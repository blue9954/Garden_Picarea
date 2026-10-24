import Foundation
import GardenCore

/// Info.plist(← xcconfig ← Secrets.xcconfig)에서 읽은 API 키와 기능 플래그.
struct AppConfiguration: Sendable {
    var naver: NaverCredentials
    var kakaoRestAPIKey: String
    var weatherKitEnabled: Bool

    static func fromBundle(_ bundle: Bundle = .main) -> AppConfiguration {
        from(info: bundle.infoDictionary ?? [:])
    }

    static func from(info: [String: Any]) -> AppConfiguration {
        func value(_ key: String) -> String {
            let raw = (info[key] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            // xcconfig 변수가 정의되지 않으면 "$(NAME)" 문자열이 그대로 남는다
            return raw.hasPrefix("$(") ? "" : raw
        }
        return AppConfiguration(
            naver: NaverCredentials(clientID: value("NaverClientID"), clientSecret: value("NaverClientSecret")),
            kakaoRestAPIKey: value("KakaoRestAPIKey"),
            weatherKitEnabled: ["yes", "true", "1"].contains(value("WeatherKitEnabled").lowercased())
        )
    }

    /// SwiftUI Preview용 (네트워크 없음).
    static let preview = AppConfiguration(naver: NaverCredentials(clientID: "", clientSecret: ""),
                                          kakaoRestAPIKey: "", weatherKitEnabled: false)

    var hasNaver: Bool { naver.isComplete }
    var hasKakao: Bool { !kakaoRestAPIKey.isEmpty }
    var hasAnySource: Bool { hasNaver || hasKakao }

    func makeEngine(weights: ScoringWeights) -> RecommendationEngine? {
        var providers: [any CommunitySearchProvider] = []
        if hasNaver {
            providers.append(ResilientProvider(NaverSearchProvider(kind: .blog, credentials: naver)))
            providers.append(ResilientProvider(NaverSearchProvider(kind: .cafearticle, credentials: naver)))
        }
        if hasKakao {
            providers.append(ResilientProvider(KakaoSearchProvider(kind: .blog, restAPIKey: kakaoRestAPIKey)))
            providers.append(ResilientProvider(KakaoSearchProvider(kind: .cafe, restAPIKey: kakaoRestAPIKey)))
        }
        guard !providers.isEmpty else { return nil }
        return RecommendationEngine(
            providers: providers,
            verifier: hasKakao ? KakaoPlaceVerifier(restAPIKey: kakaoRestAPIKey) : nil,
            weather: weatherKitEnabled ? WeatherKitProvider() : nil,
            weights: weights
        )
    }
}
