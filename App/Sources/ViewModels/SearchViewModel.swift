import Foundation
import GardenCore
import Observation

/// 홈/검색 화면 상태. 새 검색이 시작되면 이전 검색 Task를 취소한다.
@MainActor
@Observable
final class SearchViewModel {
    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case empty
        case needsSetup
        case failed(String)
    }

    var query = ""
    var selectedTheme: Theme? {
        didSet { if oldValue != selectedTheme { searchCurrent() } }
    }
    var weightsPreset: WeightsPreset = .standard {
        didSet { if oldValue != weightsPreset { rebuildEngine(); searchCurrent() } }
    }

    private(set) var phase: Phase = .idle
    private(set) var recommendations: [Recommendation] = []
    private(set) var warnings: [String] = []
    private(set) var regionName: String?
    private(set) var coordinate: Coordinate = .seoul
    private(set) var now = Date()

    let configuration: AppConfiguration
    @ObservationIgnored private var engine: RecommendationEngine?
    @ObservationIgnored private let location: any LocationProviding
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    @ObservationIgnored private var didBootstrap = false

    typealias EngineFactory = (ScoringWeights) -> RecommendationEngine?
    @ObservationIgnored private let engineFactory: EngineFactory

    /// - Parameter engineFactory: 테스트에서 Mock 엔진 주입용. 기본값은 설정의 API 키로 실제 엔진 생성.
    init(configuration: AppConfiguration, location: (any LocationProviding)? = nil,
         engineFactory: EngineFactory? = nil) {
        self.configuration = configuration
        self.location = location ?? LocationService()
        self.engineFactory = engineFactory ?? { configuration.makeEngine(weights: $0) }
        rebuildEngine()
    }

    var sunTimes: SunTimes { SolarCalculator.sunTimes(on: now, at: coordinate) }
    var season: Season { SeasonalCalendar().season(of: now) }

    /// 첫 진입: 위치 → 지역명 → 제철 테마로 자동 검색.
    func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        if let current = await location.currentCoordinate(), current.isValid {
            coordinate = current
        }
        regionName = await location.regionName(for: coordinate)
        if selectedTheme == nil {
            selectedTheme = Theme.allCases.first { $0.seasons.contains(season) } // didSet에서 검색 시작
        } else {
            searchCurrent()
        }
    }

    func submit() {
        searchCurrent()
    }

    func refresh() async {
        searchCurrent()
        await searchTask?.value
    }

    /// 진행 중인 검색이 끝날 때까지 대기 (테스트·당겨서 새로고침용).
    func waitForCurrentSearch() async {
        await searchTask?.value
    }

    /// 검색어 + 선택 테마 + (검색어에 지역이 없으면) 현재 지역을 합쳐 질의를 만든다.
    var effectiveQuery: String {
        var parts: [String] = []
        let typed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let typedHasRegion = QueryBuilder.intent(for: typed).region != nil
        if !typedHasRegion, let regionName { parts.append(regionName) }
        if !typed.isEmpty { parts.append(typed) }
        if let selectedTheme, !typed.contains(selectedTheme.koreanName) { parts.append(selectedTheme.koreanName) }
        return parts.joined(separator: " ")
    }

    private func searchCurrent() {
        searchTask?.cancel()
        guard let engine else {
            phase = .needsSetup
            return
        }
        let query = effectiveQuery
        guard !query.isEmpty else {
            phase = .idle
            return
        }
        phase = .loading
        now = Date()
        let near = coordinate
        searchTask = Task { [weak self] in
            do {
                let outcome = try await engine.recommend(query: query, near: near)
                guard !Task.isCancelled else { return }
                self?.apply(outcome)
            } catch is CancellationError {
                // 새 검색으로 대체됨 — 에러 표시 안 함
            } catch {
                self?.phase = .failed(error.localizedDescription)
            }
        }
    }

    private func apply(_ outcome: SearchOutcome) {
        recommendations = outcome.recommendations
        warnings = outcome.failures.compactMap(\.errorDescription)
        if outcome.isTotalFailure {
            phase = .failed(warnings.first ?? "검색에 실패했어요.")
        } else {
            phase = outcome.recommendations.isEmpty ? .empty : .loaded
        }
    }

    private func rebuildEngine() {
        engine = engineFactory(weightsPreset.weights)
    }
}

enum WeightsPreset: String, CaseIterable, Identifiable {
    case standard, rightNow

    var id: String { rawValue }
    var title: String {
        switch self {
        case .standard: "커뮤니티 인기 우선"
        case .rightNow: "지금 바로 출사"
        }
    }
    var weights: ScoringWeights {
        switch self {
        case .standard: .standard
        case .rightNow: .rightNow
        }
    }
}
