import Foundation
@testable import GardenCore

/// 요청을 기록하고 라우팅 클로저로 응답하는 테스트용 HTTP 클라이언트.
actor MockHTTPClient: HTTPClient {
    typealias Handler = @Sendable (HTTPRequest) throws -> HTTPResponse
    private let handler: Handler
    private(set) var requests: [HTTPRequest] = []

    init(handler: @escaping Handler) { self.handler = handler }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        requests.append(request)
        try Task.checkCancellation()
        return try handler(request)
    }

    static func json(_ body: String, status: Int = 200, headers: [String: String] = [:]) -> HTTPResponse {
        HTTPResponse(status: status, headers: headers, body: Data(body.utf8))
    }
}

enum Fixture {
    static func data(_ name: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures") else {
            throw FixtureError.missing(name)
        }
        return try Data(contentsOf: url)
    }

    /// kakao_local_jeju.json: { "<query>": <응답> } 형태.
    static func kakaoLocalTable() throws -> [String: Data] {
        let object = try JSONSerialization.jsonObject(with: data("kakao_local_jeju")) as? [String: Any] ?? [:]
        return try object.mapValues { try JSONSerialization.data(withJSONObject: $0) }
    }

    enum FixtureError: Error { case missing(String) }
}

extension HTTPRequest {
    func queryValue(_ name: String) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == name }?.value
    }
}

/// KST 기준 고정 시각 생성.
func kst(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0, _ second: Int = 0) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .seoul
    return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))!
}

func post(_ text: String, source: SourceKind = .naverBlog, url: String? = nil, date: Date? = nil) -> CommunityPost {
    CommunityPost(source: source, title: text, snippet: "", url: url ?? "https://example.com/\(UUID().uuidString)", publishedAt: date)
}

struct StubProvider: CommunitySearchProvider {
    var name: String
    var source: SourceKind
    var result: @Sendable (String) throws -> [CommunityPost]
    func search(_ query: String, limit: Int) async throws -> [CommunityPost] { try result(query) }
}
