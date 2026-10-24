import Foundation

public struct NaverCredentials: Sendable, Hashable {
    public var clientID: String
    public var clientSecret: String
    public init(clientID: String, clientSecret: String) {
        self.clientID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.clientSecret = clientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    public var isComplete: Bool { !clientID.isEmpty && !clientSecret.isEmpty }
}

/// 네이버 검색 API (블로그 / 카페글). https://developers.naver.com/docs/serviceapi/search/
public struct NaverSearchProvider: CommunitySearchProvider {
    public enum Kind: String, Sendable { case blog, cafearticle }

    public let kind: Kind
    let credentials: NaverCredentials
    let client: any HTTPClient
    static let baseURL = "https://openapi.naver.com/v1/search/"
    static let maxDisplay = 100

    public init(kind: Kind, credentials: NaverCredentials, client: any HTTPClient = URLSessionHTTPClient()) {
        self.kind = kind
        self.credentials = credentials
        self.client = client
    }

    public var name: String { source.koreanName }
    public var source: SourceKind { kind == .blog ? .naverBlog : .naverCafe }

    public func search(_ query: String, limit: Int) async throws -> [CommunityPost] {
        guard credentials.isComplete else { throw GardenError.missingCredentials(provider: name) }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let display = min(max(limit, 1), Self.maxDisplay)
        let url = try URLComponents.build(Self.baseURL + kind.rawValue + ".json",
                                          [("query", trimmed), ("display", String(display)), ("start", "1"), ("sort", "sim")],
                                          provider: name)
        let request = HTTPRequest(url: url, headers: [
            "X-Naver-Client-Id": credentials.clientID,
            "X-Naver-Client-Secret": credentials.clientSecret,
        ])
        let response = try await client.fetchJSON(NaverResponse.self, request: request, provider: name)
        return (response.items ?? []).compactMap { item in
            guard let link = item.link, !link.isEmpty else { return nil }
            return CommunityPost(
                source: source,
                title: TextNormalizer.clean(item.title ?? ""),
                snippet: TextNormalizer.clean(item.description ?? ""),
                url: link,
                author: item.bloggername ?? item.cafename,
                publishedAt: DateParsing.compactDate(item.postdate)
            )
        }
    }

    struct NaverResponse: Decodable {
        let total: Int?
        let items: [Item]?
        struct Item: Decodable {
            let title: String?
            let link: String?
            let description: String?
            let bloggername: String?
            let cafename: String?
            let postdate: String?
        }
    }
}
