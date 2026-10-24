import Foundation
import Testing
@testable import GardenCore

/// 실제 API 스모크 테스트. 환경변수에 키가 있을 때만 실행된다 (CI 기본값은 skip).
///   NAVER_CLIENT_ID=… NAVER_CLIENT_SECRET=… KAKAO_REST_API_KEY=… swift test --filter LiveSmoke
@Suite("LiveSmoke", .enabled(if: LiveKeys.available))
struct LiveSmokeTests {
    @Test func realSearchProducesVerifiedSpots() async throws {
        let env = ProcessInfo.processInfo.environment
        var providers: [any CommunitySearchProvider] = []
        if let id = env["NAVER_CLIENT_ID"], let secret = env["NAVER_CLIENT_SECRET"] {
            providers.append(NaverSearchProvider(kind: .blog, credentials: NaverCredentials(clientID: id, clientSecret: secret)))
        }
        let kakao = env["KAKAO_REST_API_KEY"]
        if let kakao { providers.append(KakaoSearchProvider(kind: .blog, restAPIKey: kakao)) }

        let engine = RecommendationEngine(providers: providers,
                                          verifier: kakao.map { KakaoPlaceVerifier(restAPIKey: $0) })
        let outcome = try await engine.recommend(query: "제주 수국")
        for r in outcome.recommendations.prefix(10) {
            print(String(format: "LIVE %-16@ %.2f 언급 %d", r.name as NSString, r.score.total, r.posts.count))
        }
        #expect(outcome.failures.isEmpty, "\(outcome.failures)")
        #expect(outcome.scannedPosts > 0)
        #expect(!outcome.recommendations.isEmpty)
    }
}

enum LiveKeys {
    static var available: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["NAVER_CLIENT_ID"] != nil || env["KAKAO_REST_API_KEY"] != nil
    }
}
