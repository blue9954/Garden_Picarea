import Foundation

/// 촬영 테마. 검색어/게시글 키워드로 감지하며 계절·시간·날씨 적합도를 정의한다.
public enum Theme: String, CaseIterable, Sendable, Codable {
    case cherryBlossom, canola, hydrangea, lotus, silverGrass, autumnLeaves
    case snowscape, nightView, milkyWay, sunrise, sunset, seaOfClouds

    /// 테마가 잘 맞는 시간대.
    public enum TimePreference: Sendable {
        case daylight      // 꽃·단풍 등: 낮 + 골든아워
        case morningGolden // 일출, 운해
        case eveningGolden // 일몰
        case night         // 야경, 은하수
    }

    public var koreanName: String {
        switch self {
        case .cherryBlossom: "벚꽃"
        case .canola: "유채꽃"
        case .hydrangea: "수국"
        case .lotus: "연꽃"
        case .silverGrass: "억새"
        case .autumnLeaves: "단풍"
        case .snowscape: "설경"
        case .nightView: "야경"
        case .milkyWay: "은하수"
        case .sunrise: "일출"
        case .sunset: "일몰"
        case .seaOfClouds: "운해"
        }
    }

    /// 감지용 키워드 (첫 번째가 대표어).
    public var keywords: [String] {
        switch self {
        case .cherryBlossom: ["벚꽃", "벚나무", "왕벚"]
        case .canola: ["유채꽃", "유채"]
        case .hydrangea: ["수국"]
        case .lotus: ["연꽃", "연지", "홍련", "백련"]
        case .silverGrass: ["억새", "핑크뮬리", "갈대"]
        case .autumnLeaves: ["단풍", "은행나무", "가을길"]
        case .snowscape: ["설경", "눈꽃", "상고대"]
        case .nightView: ["야경", "야간", "불빛"]
        case .milkyWay: ["은하수", "별사진", "별궤적", "천체"]
        case .sunrise: ["일출", "해돋이"]
        case .sunset: ["일몰", "노을", "석양", "해넘이"]
        case .seaOfClouds: ["운해", "구름바다"]
        }
    }

    /// 제철 계절. 비어 있으면 사계절.
    public var seasons: Set<Season> {
        switch self {
        case .cherryBlossom, .canola: [.spring]
        case .hydrangea, .lotus: [.summer]
        case .silverGrass, .autumnLeaves: [.autumn]
        case .snowscape: [.winter]
        case .milkyWay: [.spring, .summer, .autumn]
        case .seaOfClouds: [.autumn, .spring]
        case .nightView, .sunrise, .sunset: []
        }
    }

    public var timePreference: TimePreference {
        switch self {
        case .nightView, .milkyWay: .night
        case .sunrise, .seaOfClouds: .morningGolden
        case .sunset: .eveningGolden
        default: .daylight
        }
    }

    /// 하늘 상태별 적합도 (0~1).
    public func weatherFitness(_ sky: SkyCondition) -> Double {
        switch (self, sky) {
        case (_, .unknown): 0.5
        case (.milkyWay, .clear): 1.0
        case (.milkyWay, .partlyCloudy): 0.5
        case (.milkyWay, _): 0.05
        case (.seaOfClouds, .fog): 1.0
        case (.seaOfClouds, .cloudy): 0.7
        case (.seaOfClouds, .clear), (.seaOfClouds, .partlyCloudy): 0.6
        case (.snowscape, .snow): 1.0
        case (.snowscape, .clear): 0.8
        case (.sunrise, .partlyCloudy), (.sunset, .partlyCloudy): 1.0
        case (.sunrise, .clear), (.sunset, .clear): 0.85
        case (.sunrise, .cloudy), (.sunset, .cloudy): 0.3
        case (.hydrangea, .rain), (.lotus, .rain): 0.6 // 비 맞은 수국·연꽃은 오히려 인기
        case (_, .clear): 0.9
        case (_, .partlyCloudy): 1.0
        case (_, .cloudy): 0.6
        case (_, .fog): 0.5
        case (_, .snow): 0.4
        case (_, .rain): 0.2
        }
    }

    /// 텍스트에서 테마 감지.
    public static func detect(in text: String) -> Set<Theme> {
        Set(allCases.filter { theme in theme.keywords.contains { text.contains($0) } })
    }
}
