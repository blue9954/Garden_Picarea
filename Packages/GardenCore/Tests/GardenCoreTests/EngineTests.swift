import Foundation
import Testing
@testable import GardenCore

/// 픽스처 → 실제 Provider/Verifier 구조체 → Engine 전 구간 통합 테스트.
@Suite("RecommendationEngine")
struct EngineTests {
    static let now = kst(2025, 6, 20, 18, 0)

    static func fixtureClient(failing: Set<String> = []) throws -> MockHTTPClient {
        let naver = try Fixture.data("naver_blog_jeju_hydrangea")
        let kakao = try Fixture.data("kakao_blog_jeju_hydrangea")
        let local = try Fixture.kakaoLocalTable()
        return MockHTTPClient { request in
            let path = request.url.path
            if failing.contains(path) { return MockHTTPClient.json("{}", status: 401) }
            switch path {
            case "/v1/search/blog.json": return HTTPResponse(status: 200, body: naver)
            case "/v2/search/blog": return HTTPResponse(status: 200, body: kakao)
            case "/v2/local/search/keyword.json":
                return HTTPResponse(status: 200, body: local[request.queryValue("query") ?? ""] ?? Data(#"{"documents":[]}"#.utf8))
            default: return MockHTTPClient.json(#"{"items":[],"documents":[]}"#)
            }
        }
    }

    static func engine(client: MockHTTPClient, weather: SkyCondition = .partlyCloudy) -> RecommendationEngine {
        RecommendationEngine(
            providers: [
                NaverSearchProvider(kind: .blog, credentials: NaverCredentials(clientID: "i", clientSecret: "s"), client: client),
                KakaoSearchProvider(kind: .blog, restAPIKey: "k", client: client),
            ],
            verifier: KakaoPlaceVerifier(restAPIKey: "k", client: client),
            weather: StaticWeatherProvider(weather),
            now: { now }
        )
    }

    @Test func endToEndRanksVerifiedSpots() async throws {
        let client = try Self.fixtureClient()
        let outcome = try await Self.engine(client: client).recommend(query: "제주 수국")

        #expect(outcome.failures.isEmpty)
        // 네이버 8 + 카카오 4 - 미러 중복 1 (질의 2개지만 URL 중복 제거)
        #expect(outcome.scannedPosts == 11)

        let names = outcome.recommendations.map(\.name)
        // 보롬왓·혼인지는 픽스처상 언급 수/출처/계절이 같아 동점 → 상위 2개 집합으로 검증
        #expect(Set(names.prefix(2)) == ["보롬왓", "혼인지"])
        #expect(names.last == "카멜리아힐") // 12월 글이 섞여 계절 점수가 가장 낮음
        #expect(Set(names) == ["보롬왓", "휴애리자연생활공원", "혼인지", "카멜리아힐"])
        #expect(!names.contains("가짜오름"))           // 카카오 로컬에 없는 거짓 양성 제거
        #expect(!names.contains { $0.contains("주차장") })

        let top = try #require(outcome.recommendations.first { $0.name == "보롬왓" })
        #expect(top.place?.coordinate.latitude ?? 0 > 33)
        #expect(top.themes.contains(.hydrangea))
        #expect(top.sources == [.naverBlog, .daumBlog])
        #expect(top.sky == .partlyCloudy)
        #expect(outcome.recommendations.map(\.score.total) == outcome.recommendations.map(\.score.total).sorted(by: >))
        #expect(outcome.recommendations.allSatisfy { (0...1).contains($0.score.total) })
    }

    @Test func inSeasonSpotOutranksOffSeasonMentions() async throws {
        let outcome = try await Self.engine(client: try Self.fixtureClient()).recommend(query: "제주 수국")
        let byName = Dictionary(uniqueKeysWithValues: outcome.recommendations.map { ($0.name, $0) })
        // 카멜리아힐 언급은 12월 글 → 6월 기준 계절 점수가 낮아야 한다
        let camellia = try #require(byName["카멜리아힐"])
        let honinji = try #require(byName["혼인지"])
        #expect(honinji.score.season > camellia.score.season)
    }

    @Test func partialProviderFailureStillReturnsResults() async throws {
        let client = try Self.fixtureClient(failing: ["/v2/search/blog"])
        let outcome = try await Self.engine(client: client).recommend(query: "제주 수국")
        #expect(!outcome.recommendations.isEmpty)
        #expect(outcome.failures == [.unauthorized(provider: "다음 블로그")]) // 질의 2회 실패해도 1번만 보고
        #expect(!outcome.isTotalFailure)
    }

    @Test func totalFailureIsReported() async throws {
        let client = try Self.fixtureClient(failing: ["/v1/search/blog.json", "/v2/search/blog"])
        let outcome = try await Self.engine(client: client).recommend(query: "제주 수국")
        #expect(outcome.recommendations.isEmpty)
        #expect(outcome.isTotalFailure)
        #expect(outcome.failures.count == 2)
    }

    @Test func verifierOutageKeepsUnverifiedCandidates() async throws {
        let client = try Self.fixtureClient(failing: ["/v2/local/search/keyword.json"])
        let outcome = try await Self.engine(client: client).recommend(query: "제주 수국")
        #expect(outcome.recommendations.contains { $0.name == "보롬왓" && $0.place == nil })
        #expect(outcome.failures == [.unauthorized(provider: "카카오 로컬")])
    }

    @Test func weatherChangesOrderingForMilkyWay() async throws {
        let posts = [
            post("안반데기 은하수", date: kst(2024, 6, 1)), post("안반데기 은하수 별사진", date: kst(2023, 6, 3)),
        ]
        let provider = StubProvider(name: "stub", source: .naverBlog) { _ in posts }
        func run(_ sky: SkyCondition) async throws -> Double {
            let engine = RecommendationEngine(providers: [provider], weather: StaticWeatherProvider(sky), now: { kst(2025, 6, 21, 0, 30) })
            return try #require(try await engine.recommend(query: "강원 은하수").recommendations.first).score.total
        }
        #expect(try await run(.clear) > run(.rain))
    }

    @Test func emptyQueryMakesNoRequests() async throws {
        let client = try Self.fixtureClient()
        let outcome = try await Self.engine(client: client).recommend(query: "  ")
        #expect(outcome.recommendations.isEmpty && outcome.failures.isEmpty)
        #expect(await client.requests.isEmpty)
    }

    @Test func cancellationPropagates() async throws {
        let slow = StubProvider(name: "slow", source: .naverBlog) { _ in
            Thread.sleep(forTimeInterval: 0.2)
            return [post("보롬왓"), post("보롬왓")]
        }
        let engine = RecommendationEngine(providers: [slow], now: { Self.now })
        let task = Task { try await engine.recommend(query: "제주 수국") }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
    }
}
