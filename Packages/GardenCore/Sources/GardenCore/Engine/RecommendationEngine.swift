import Foundation

public struct SearchOutcome: Sendable {
    public var intent: SearchIntent
    public var recommendations: [Recommendation]
    /// Provider별 첫 실패 (부분 실패 배너용).
    public var failures: [GardenError]
    public var scannedPosts: Int

    /// 모든 출처가 실패해서 결과가 비었는지 여부.
    public var isTotalFailure: Bool { recommendations.isEmpty && scannedPosts == 0 && !failures.isEmpty }
}

/// 검색 → 추출 → 검증 → 맥락 점수화 → 정렬 파이프라인.
public struct RecommendationEngine: Sendable {
    public struct Configuration: Sendable {
        public var postsPerQuery = 50
        public var maxQueries = 2
        public var maxCandidatesToVerify = 12
        public var maxResults = 20
        /// 지배 테마로 인정할 게시글 비율.
        public var dominantThemeRatio = 0.4
        public init() {}
    }

    let providers: [any CommunitySearchProvider]
    let verifier: (any PlaceVerifier)?
    let weather: (any WeatherProvider)?
    let scorer: Scorer
    let extractor: SpotExtractor
    let timeZone: TimeZone
    let now: @Sendable () -> Date
    public var configuration: Configuration

    public init(providers: [any CommunitySearchProvider],
                verifier: (any PlaceVerifier)? = nil,
                weather: (any WeatherProvider)? = nil,
                weights: ScoringWeights = .standard,
                timeZone: TimeZone = .seoul,
                configuration: Configuration = Configuration(),
                now: @escaping @Sendable () -> Date = Date.init) {
        self.providers = providers
        self.verifier = verifier
        self.weather = weather
        self.scorer = Scorer(weights: weights, calendar: SeasonalCalendar(timeZone: timeZone))
        self.extractor = SpotExtractor()
        self.timeZone = timeZone
        self.configuration = configuration
        self.now = now
    }

    /// 취소 시에만 throw. 그 외 실패는 `SearchOutcome.failures`로 돌려준다.
    public func recommend(query: String, near userLocation: Coordinate? = nil) async throws -> SearchOutcome {
        let intent = QueryBuilder.intent(for: query, maxQueries: configuration.maxQueries)
        guard !intent.queries.isEmpty, !providers.isEmpty else {
            return SearchOutcome(intent: intent, recommendations: [], failures: [], scannedPosts: 0)
        }
        var failures = FailureLog()

        // 1) 커뮤니티 검색 (Provider × 질의 병렬)
        let (posts, activeSources) = try await fetchPosts(intent: intent, failures: &failures)
        try Task.checkCancellation()

        // 2) 후보 추출
        var candidates = extractor.extract(from: posts, intent: intent)
        if (candidates.first?.mentionCount ?? 0) >= 2 {
            candidates = candidates.filter { $0.mentionCount >= 2 }
        }
        candidates = Array(candidates.prefix(configuration.maxCandidatesToVerify))

        // 3) 실존 검증 + 동일 장소 병합
        let spots = try await verify(candidates, intent: intent, failures: &failures)
        try Task.checkCancellation()

        // 4) 날씨 (좌표 반올림 단위로 1회씩)
        let fallback = userLocation ?? .seoul
        let skies = try await fetchWeather(for: spots.map { $0.place?.coordinate ?? fallback }, failures: &failures)

        // 5) 점수화
        let current = now()
        let maxMentions = spots.map(\.posts.count).max() ?? 1
        let recommendations = spots.map { spot -> Recommendation in
            let coordinate = spot.place?.coordinate ?? fallback
            let themes = intent.themes.union(dominantThemes(in: spot.posts))
            let sky = skies[coordinate.rounded()] ?? .unknown
            let sun = SolarCalculator.sunTimes(on: current, at: coordinate, timeZone: timeZone)
            let elevation = SolarCalculator.elevation(at: current, coordinate: coordinate)
            let score = scorer.total(
                community: scorer.community(posts: spot.posts, maxMentions: maxMentions,
                                            activeSourceCount: activeSources, now: current),
                season: scorer.season(posts: spot.posts, themes: themes, now: current),
                weather: scorer.weather(themes: themes, sky: sky),
                time: scorer.time(themes: themes, now: current, sun: sun, elevation: elevation)
            )
            return Recommendation(name: spot.place?.name ?? spot.name, place: spot.place, posts: spot.posts,
                                  themes: themes, sky: sky, score: score)
        }
        .sorted { $0.score.total == $1.score.total ? $0.name < $1.name : $0.score.total > $1.score.total }

        return SearchOutcome(intent: intent, recommendations: Array(recommendations.prefix(configuration.maxResults)),
                             failures: failures.errors, scannedPosts: posts.count)
    }

    // MARK: - Steps

    struct Spot {
        var name: String
        var place: VerifiedPlace?
        var posts: [CommunityPost]
    }

    func fetchPosts(intent: SearchIntent, failures: inout FailureLog) async throws -> ([CommunityPost], Int) {
        let limit = configuration.postsPerQuery
        let results = await withTaskGroup(of: (String, SourceKind, Result<[CommunityPost], Error>).self) { group in
            for provider in providers {
                for query in intent.queries {
                    group.addTask {
                        do { return (provider.name, provider.source, .success(try await provider.search(query, limit: limit))) }
                        catch { return (provider.name, provider.source, .failure(error)) }
                    }
                }
            }
            var collected: [(String, SourceKind, Result<[CommunityPost], Error>)] = []
            for await result in group { collected.append(result) }
            return collected
        }
        try Task.checkCancellation()

        var seen = Set<String>()
        var posts: [CommunityPost] = []
        var activeSources = Set<SourceKind>()
        for (name, source, result) in results {
            switch result {
            case .success(let batch):
                activeSources.insert(source)
                for post in batch where seen.insert(Self.urlKey(post.url)).inserted { posts.append(post) }
            case .failure(let error):
                if error is CancellationError { throw error }
                failures.record(error, provider: name)
            }
        }
        // TaskGroup 완료 순서는 비결정적 → 결과 안정화를 위해 정렬
        posts.sort { $0.url < $1.url }
        return (posts, activeSources.count)
    }

    func verify(_ candidates: [SpotCandidate], intent: SearchIntent, failures: inout FailureLog) async throws -> [Spot] {
        guard let verifier else {
            return candidates.map { Spot(name: $0.name, place: nil, posts: $0.posts) }
        }
        let results = await withTaskGroup(of: (Int, Result<VerifiedPlace?, Error>).self) { group in
            for (index, candidate) in candidates.enumerated() {
                group.addTask {
                    do { return (index, .success(try await verifier.verify(candidate, regionHint: candidate.dominantRegion ?? intent.region))) }
                    catch { return (index, .failure(error)) }
                }
            }
            var collected: [(Int, Result<VerifiedPlace?, Error>)] = []
            for await result in group { collected.append(result) }
            return collected.sorted { $0.0 < $1.0 }
        }
        try Task.checkCancellation()

        var spots: [Spot] = []
        var indexByPlace: [String: Int] = [:]
        for (index, result) in results {
            let candidate = candidates[index]
            switch result {
            case .success(.some(let place)):
                if let existing = indexByPlace[place.id] {
                    let known = Set(spots[existing].posts.map(\.url))
                    spots[existing].posts += candidate.posts.filter { !known.contains($0.url) }
                } else {
                    indexByPlace[place.id] = spots.count
                    spots.append(Spot(name: candidate.name, place: place, posts: candidate.posts))
                }
            case .success(.none):
                continue // 실존하지 않는 후보 → 거짓 양성으로 제거
            case .failure(let error):
                if error is CancellationError { throw error }
                failures.record(error, provider: "카카오 로컬")
                spots.append(Spot(name: candidate.name, place: nil, posts: candidate.posts)) // 검증 불가 → 미검증으로 유지
            }
        }
        return spots
    }

    func fetchWeather(for coordinates: [Coordinate], failures: inout FailureLog) async throws -> [Coordinate: SkyCondition] {
        guard let weather else { return [:] }
        let unique = Array(Set(coordinates.map { $0.rounded() }))
        let date = now()
        let results = await withTaskGroup(of: (Coordinate, Result<SkyCondition, Error>).self) { group in
            for coordinate in unique {
                group.addTask {
                    do { return (coordinate, .success(try await weather.sky(at: coordinate, date: date))) }
                    catch { return (coordinate, .failure(error)) }
                }
            }
            var collected: [(Coordinate, Result<SkyCondition, Error>)] = []
            for await result in group { collected.append(result) }
            return collected
        }
        var skies: [Coordinate: SkyCondition] = [:]
        for (coordinate, result) in results {
            switch result {
            case .success(let sky): skies[coordinate] = sky
            case .failure(let error):
                if error is CancellationError { throw error }
                failures.record(error, provider: "날씨")
            }
        }
        return skies
    }

    func dominantThemes(in posts: [CommunityPost]) -> Set<Theme> {
        guard posts.count >= 2 else { return [] }
        var counts: [Theme: Int] = [:]
        for post in posts {
            for theme in Theme.detect(in: post.fullText) { counts[theme, default: 0] += 1 }
        }
        let threshold = Double(posts.count) * configuration.dominantThemeRatio
        return Set(counts.filter { Double($0.value) >= threshold && $0.value >= 2 }.keys)
    }

    static func urlKey(_ url: String) -> String {
        var key = url.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["https://", "http://", "m."] where key.hasPrefix(prefix) { key.removeFirst(prefix.count) }
        while key.hasSuffix("/") { key.removeLast() }
        return key
    }
}

/// Provider별 첫 실패만 기록.
struct FailureLog {
    private(set) var errors: [GardenError] = []
    private var providers = Set<String>()

    mutating func record(_ error: Error, provider: String) {
        guard providers.insert(provider).inserted else { return }
        errors.append(error as? GardenError ?? .transport(provider: provider, message: String(describing: error)))
    }
}
