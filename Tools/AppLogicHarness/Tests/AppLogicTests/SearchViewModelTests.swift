import Foundation
import GardenCore
import Testing
@testable import AppLogic

struct StubProvider: CommunitySearchProvider {
    var name = "stub"
    var source = SourceKind.naverBlog
    var handler: @Sendable (String) async throws -> [CommunityPost]
    func search(_ query: String, limit: Int) async throws -> [CommunityPost] { try await handler(query) }
}

/// 받은 질의를 기록하는 스레드 안전 저장소.
final class QueryLog: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [String] = []
    func append(_ q: String) { lock.lock(); items.append(q); lock.unlock() }
    var all: [String] { lock.lock(); defer { lock.unlock() }; return items }
}

func posts(_ names: [String]) -> [CommunityPost] {
    names.enumerated().map { i, n in
        CommunityPost(source: .naverBlog, title: "#\(n) 출사", snippet: "", url: "https://e.com/\(n)/\(i)")
    }
}

let keyed = AppConfiguration.from(info: ["NaverClientID": "id", "NaverClientSecret": "secret"])

@MainActor
@Suite("SearchViewModel")
struct SearchViewModelTests {
    func makeViewModel(region: String? = "제주",
                       handler: @escaping @Sendable (String) async throws -> [CommunityPost]) -> SearchViewModel {
        SearchViewModel(configuration: keyed, location: FixedLocationProvider(region: region)) { weights in
            RecommendationEngine(providers: [StubProvider(handler: handler)], weights: weights)
        }
    }

    @Test func bootstrapPicksInSeasonThemeAndLocalRegion() async {
        let log = QueryLog()
        let vm = makeViewModel { q in log.append(q); return posts(["보롬왓", "보롬왓"]) }
        await vm.bootstrap()
        await vm.waitForCurrentSearch()

        let season = SeasonalCalendar().season(of: Date())
        let expectedTheme = Theme.allCases.first { $0.seasons.contains(season) }!
        #expect(vm.selectedTheme == expectedTheme)
        #expect(vm.effectiveQuery == "제주 \(expectedTheme.koreanName)")
        #expect(log.all.allSatisfy { $0.hasPrefix("제주 \(expectedTheme.koreanName)") })
        #expect(vm.phase == .loaded)
        #expect(vm.recommendations.first?.name == "보롬왓")
    }

    @Test func typedRegionOverridesDeviceRegion() async {
        let vm = makeViewModel { _ in [] }
        vm.query = "야경"
        #expect(vm.effectiveQuery == "야경") // 위치 확인 전에는 지역 없음
        await vm.bootstrap()
        await vm.waitForCurrentSearch()
        vm.selectedTheme = nil
        #expect(vm.effectiveQuery == "제주 야경") // 기기 지역 보강
        vm.query = "부산 야경"
        #expect(vm.effectiveQuery == "부산 야경") // 입력한 지역이 우선
        vm.selectedTheme = .sunset
        #expect(vm.effectiveQuery == "부산 야경 일몰")
    }

    @Test func themeIsNotDuplicatedWhenTyped() async {
        let vm = makeViewModel { _ in [] }
        await vm.bootstrap()
        await vm.waitForCurrentSearch()
        vm.query = "서울 \(vm.selectedTheme!.koreanName)"
        #expect(vm.effectiveQuery == "서울 \(vm.selectedTheme!.koreanName)")
    }

    @Test func needsSetupWithoutKeys() async {
        let vm = SearchViewModel(configuration: .preview, location: FixedLocationProvider())
        await vm.bootstrap()
        #expect(vm.phase == .needsSetup)
    }

    @Test func totalFailureShowsError() async {
        let vm = makeViewModel { _ in throw GardenError.unauthorized(provider: "stub") }
        await vm.bootstrap()
        await vm.waitForCurrentSearch()
        guard case .failed(let message) = vm.phase else {
            Issue.record("expected failed, got \(vm.phase)")
            return
        }
        #expect(message.contains("인증"))
    }

    @Test func emptyResultIsDistinguishedFromFailure() async {
        let vm = makeViewModel { _ in [] }
        await vm.bootstrap()
        await vm.waitForCurrentSearch()
        #expect(vm.phase == .empty)
    }

    @Test func newerSearchWinsOverSlowerOlderOne() async throws {
        let vm = makeViewModel { q in
            if q.contains("느린") {
                try await Task.sleep(for: .milliseconds(300))
                return posts(["옛날오름", "옛날오름"])
            }
            return posts(["새별오름", "새별오름"])
        }
        vm.query = "느린"
        vm.submit()
        try await Task.sleep(for: .milliseconds(20))
        vm.query = "빠른"
        vm.submit()
        await vm.waitForCurrentSearch()
        try await Task.sleep(for: .milliseconds(400)) // 취소된 이전 검색이 늦게 끝나도 덮어쓰면 안 됨
        #expect(vm.recommendations.map(\.name) == ["새별오름"])
        #expect(vm.phase == .loaded)
    }
}

@Suite("AppConfiguration")
struct AppConfigurationTests {
    @Test func unresolvedXcconfigVariablesAreTreatedAsMissing() {
        let config = AppConfiguration.from(info: [
            "NaverClientID": "$(NAVER_CLIENT_ID)", "NaverClientSecret": "s",
            "KakaoRestAPIKey": "  kakao  ", "WeatherKitEnabled": "YES",
        ])
        #expect(!config.hasNaver)
        #expect(config.hasKakao && config.kakaoRestAPIKey == "kakao")
        #expect(config.weatherKitEnabled)
    }

    @Test func engineIsBuiltOnlyWithKeys() {
        #expect(AppConfiguration.preview.makeEngine(weights: .standard) == nil)
        #expect(keyed.makeEngine(weights: .standard) != nil)
    }
}
