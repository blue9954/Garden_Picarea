import Foundation

/// 카카오 로컬 등으로 실존 검증된 장소.
public struct VerifiedPlace: Hashable, Sendable, Codable {
    public var id: String
    public var name: String
    public var address: String
    public var category: String
    public var coordinate: Coordinate
    public var placeURL: String?

    public init(id: String, name: String, address: String, category: String,
                coordinate: Coordinate, placeURL: String? = nil) {
        self.id = id
        self.name = name
        self.address = address
        self.category = category
        self.coordinate = coordinate
        self.placeURL = placeURL
    }
}

/// 점수 세부 내역 (모두 0~1).
public struct ScoreBreakdown: Hashable, Sendable, Codable {
    public var community: Double
    public var season: Double
    public var weather: Double
    public var time: Double
    public var total: Double

    public init(community: Double, season: Double, weather: Double, time: Double, total: Double) {
        self.community = community
        self.season = season
        self.weather = weather
        self.time = time
        self.total = total
    }
}

public struct Recommendation: Hashable, Sendable, Identifiable {
    public var id: String { place?.id ?? "candidate:" + name }
    /// 표시 이름 (검증 시 카카오 장소명).
    public var name: String
    public var place: VerifiedPlace?
    public var posts: [CommunityPost]
    public var themes: Set<Theme>
    public var sky: SkyCondition
    public var score: ScoreBreakdown

    public init(name: String, place: VerifiedPlace?, posts: [CommunityPost], themes: Set<Theme>,
                sky: SkyCondition, score: ScoreBreakdown) {
        self.name = name
        self.place = place
        self.posts = posts
        self.themes = themes
        self.sky = sky
        self.score = score
    }

    public var sources: Set<SourceKind> { Set(posts.map(\.source)) }
}
