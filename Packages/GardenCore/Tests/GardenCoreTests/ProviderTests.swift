import Foundation
import Testing
@testable import GardenCore

@Suite("Providers")
struct ProviderTests {
    static let naverKeys = NaverCredentials(clientID: "id", clientSecret: "secret")

    @Test func naverBlogParsesFixtureAndSendsHeaders() async throws {
        let body = try Fixture.data("naver_blog_jeju_hydrangea")
        let client = MockHTTPClient { _ in HTTPResponse(status: 200, body: body) }
        let provider = NaverSearchProvider(kind: .blog, credentials: Self.naverKeys, client: client)
        let posts = try await provider.search("제주 수국 출사", limit: 500)

        #expect(posts.count == 8)
        #expect(posts[0].title == "제주 수국 명소 보롬왓 다녀왔어요")
        #expect(posts[0].snippet.contains("#보롬왓 & 혼인지"))
        #expect(posts[0].publishedAt == kst(2024, 6, 18, 12))
        #expect(posts.allSatisfy { $0.source == .naverBlog })

        let request = try #require(await client.requests.first)
        #expect(request.url.path == "/v1/search/blog.json")
        #expect(request.headers["X-Naver-Client-Id"] == "id")
        #expect(request.headers["X-Naver-Client-Secret"] == "secret")
        #expect(request.queryValue("query") == "제주 수국 출사")
        #expect(request.queryValue("display") == "100") // 최대값으로 클램프
    }

    @Test func kakaoBlogParsesIsoDatesWithAndWithoutFraction() async throws {
        let body = try Fixture.data("kakao_blog_jeju_hydrangea")
        let client = MockHTTPClient { _ in HTTPResponse(status: 200, body: body) }
        let provider = KakaoSearchProvider(kind: .blog, restAPIKey: " key ", client: client)
        let posts = try await provider.search("제주 수국", limit: 10)

        #expect(posts.count == 4)
        #expect(posts[0].publishedAt == kst(2024, 6, 22, 19, 30))
        #expect(posts[2].publishedAt == kst(2023, 6, 28, 8, 10))
        let request = try #require(await client.requests.first)
        #expect(request.headers["Authorization"] == "KakaoAK key")
        #expect(request.url.path == "/v2/search/blog")
    }

    @Test func plusSignIsPercentEncoded() async throws {
        let client = MockHTTPClient { _ in MockHTTPClient.json(#"{"documents":[]}"#) }
        _ = try await KakaoSearchProvider(kind: .cafe, restAPIKey: "k", client: client).search("C++ 야경", limit: 5)
        let request = try #require(await client.requests.first)
        #expect(request.url.absoluteString.contains("C%2B%2B"))
    }

    @Test func missingCredentialsFailsWithoutNetworkCall() async {
        let client = MockHTTPClient { _ in MockHTTPClient.json("{}") }
        let provider = NaverSearchProvider(kind: .cafearticle, credentials: NaverCredentials(clientID: "", clientSecret: "x"), client: client)
        await #expect(throws: GardenError.missingCredentials(provider: "네이버 카페")) {
            try await provider.search("서울 야경", limit: 10)
        }
        #expect(await client.requests.isEmpty)
    }

    @Test(arguments: [
        (401, GardenError.unauthorized(provider: "다음 블로그")),
        (429, GardenError.rateLimited(provider: "다음 블로그", retryAfter: 12)),
        (500, GardenError.http(provider: "다음 블로그", status: 500)),
    ])
    func httpErrorsAreMapped(status: Int, expected: GardenError) async {
        let client = MockHTTPClient { _ in MockHTTPClient.json("{}", status: status, headers: ["Retry-After": "12"]) }
        let provider = KakaoSearchProvider(kind: .blog, restAPIKey: "k", client: client)
        await #expect(throws: expected) { try await provider.search("q", limit: 1) }
    }

    @Test func malformedJSONBecomesDecodingError() async {
        let client = MockHTTPClient { _ in MockHTTPClient.json("<html>maintenance</html>") }
        let provider = KakaoSearchProvider(kind: .blog, restAPIKey: "k", client: client)
        await #expect {
            try await provider.search("q", limit: 1)
        } throws: { error in
            if case GardenError.decoding = error { return true }
            return false
        }
    }

    @Test func missingOptionalFieldsAreTolerated() async throws {
        let client = MockHTTPClient { _ in MockHTTPClient.json(#"{"items":[{"link":"https://x"},{"title":"no link"}]}"#) }
        let posts = try await NaverSearchProvider(kind: .cafearticle, credentials: Self.naverKeys, client: client).search("q", limit: 1)
        #expect(posts.count == 1)
        #expect(posts[0].publishedAt == nil)
    }
}

@Suite("KakaoPlaceVerifier")
struct KakaoPlaceVerifierTests {
    func verifier() throws -> (KakaoPlaceVerifier, MockHTTPClient) {
        let table = try Fixture.kakaoLocalTable()
        let client = MockHTTPClient { request in
            HTTPResponse(status: 200, body: table[request.queryValue("query") ?? ""] ?? Data(#"{"documents":[]}"#.utf8))
        }
        return (KakaoPlaceVerifier(restAPIKey: "k", client: client), client)
    }

    func candidate(_ name: String) -> SpotCandidate {
        SpotCandidate(key: TextNormalizer.key(name), name: name, posts: [], regionHints: [:])
    }

    @Test func skipsParkingLotAndPrefersExactName() async throws {
        let (verifier, _) = try verifier()
        let place = try #require(try await verifier.verify(candidate("보롬왓"), regionHint: "제주"))
        #expect(place.name == "보롬왓")
        #expect(place.id == "kakao:1002")
        #expect(place.address.contains("번영로"))
    }

    @Test func acceptsLongerOfficialName() async throws {
        let (verifier, _) = try verifier()
        let place = try await verifier.verify(candidate("휴애리"), regionHint: "제주")
        #expect(place?.name == "휴애리자연생활공원")
    }

    @Test func unknownPlaceFallsBackToPlainQueryThenNil() async throws {
        let (verifier, client) = try verifier()
        #expect(try await verifier.verify(candidate("가짜오름"), regionHint: "제주") == nil)
        #expect(await client.requests.compactMap { $0.queryValue("query") } == ["제주 가짜오름", "가짜오름"])
    }
}

@Suite("ResilientProvider")
struct ResilientProviderTests {
    final class Counter: @unchecked Sendable {
        private let lock = NSLock()
        private var value = 0
        func next() -> Int { lock.lock(); defer { lock.unlock() }; value += 1; return value }
        var count: Int { lock.lock(); defer { lock.unlock() }; return value }
    }

    @Test func cachesSuccessfulResponses() async throws {
        let counter = Counter()
        let base = StubProvider(name: "stub", source: .naverBlog) { _ in _ = counter.next(); return [post("보롬왓")] }
        let provider = ResilientProvider(base)
        _ = try await provider.search("q", limit: 10)
        _ = try await provider.search("q", limit: 10)
        #expect(counter.count == 1)
    }

    @Test func rateLimitOpensCooldownWithoutHittingBase() async throws {
        let counter = Counter()
        let base = StubProvider(name: "stub", source: .naverBlog) { _ in
            _ = counter.next()
            throw GardenError.rateLimited(provider: "stub", retryAfter: nil)
        }
        let provider = ResilientProvider(base)
        await #expect(throws: GardenError.self) { try await provider.search("a", limit: 1) }
        await #expect(throws: GardenError.self) { try await provider.search("b", limit: 1) }
        #expect(counter.count == 1)
    }

    @Test func cacheExpiresAfterTTL() async throws {
        let clock = TestClock(kst(2025, 1, 1))
        let counter = Counter()
        let base = StubProvider(name: "stub", source: .naverBlog) { _ in _ = counter.next(); return [] }
        let provider = ResilientProvider(base, cacheTTL: 60, now: { clock.now })
        _ = try await provider.search("q", limit: 1)
        clock.advance(61)
        _ = try await provider.search("q", limit: 1)
        #expect(counter.count == 2)
    }
}

final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date
    init(_ start: Date) { current = start }
    var now: Date { lock.lock(); defer { lock.unlock() }; return current }
    func advance(_ seconds: TimeInterval) { lock.lock(); current += seconds; lock.unlock() }
}
