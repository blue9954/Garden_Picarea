import Foundation

public enum SourceKind: String, CaseIterable, Sendable, Codable {
    case naverBlog, naverCafe, daumBlog, daumCafe

    public var koreanName: String {
        switch self {
        case .naverBlog: "네이버 블로그"
        case .naverCafe: "네이버 카페"
        case .daumBlog: "다음 블로그"
        case .daumCafe: "다음 카페"
        }
    }
}

/// 정규화된 커뮤니티 게시글 (HTML 제거 완료).
public struct CommunityPost: Hashable, Sendable, Codable, Identifiable {
    public var id: String { url }
    public var source: SourceKind
    public var title: String
    public var snippet: String
    public var url: String
    public var author: String?
    /// 카페 검색 등 날짜가 없는 출처는 nil.
    public var publishedAt: Date?

    public init(source: SourceKind, title: String, snippet: String, url: String,
                author: String? = nil, publishedAt: Date? = nil) {
        self.source = source
        self.title = title
        self.snippet = snippet
        self.url = url
        self.author = author
        self.publishedAt = publishedAt
    }

    public var fullText: String { title + " " + snippet }
}
