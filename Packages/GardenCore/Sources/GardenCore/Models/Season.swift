import Foundation

public enum Season: String, CaseIterable, Sendable, Codable {
    case spring, summer, autumn, winter

    public var koreanName: String {
        switch self {
        case .spring: "봄"
        case .summer: "여름"
        case .autumn: "가을"
        case .winter: "겨울"
        }
    }

    /// 북반구(대한민국) 기상학적 계절: 3–5 봄, 6–8 여름, 9–11 가을, 12–2 겨울.
    public init(month: Int) {
        switch month {
        case 3...5: self = .spring
        case 6...8: self = .summer
        case 9...11: self = .autumn
        default: self = .winter
        }
    }
}

public enum SkyCondition: String, CaseIterable, Sendable, Codable {
    case clear, partlyCloudy, cloudy, fog, rain, snow, unknown

    public var koreanName: String {
        switch self {
        case .clear: "맑음"
        case .partlyCloudy: "구름 조금"
        case .cloudy: "흐림"
        case .fog: "안개"
        case .rain: "비"
        case .snow: "눈"
        case .unknown: "알 수 없음"
        }
    }
}
