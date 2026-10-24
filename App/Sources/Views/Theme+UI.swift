import GardenCore
import SwiftUI

extension Color {
    /// Garden 브랜드 컬러 (Assets의 AccentColor와 동일).
    static let gardenGreen = Color("AccentColor")
}

extension Theme {
    var symbolName: String {
        switch self {
        case .cherryBlossom: "camera.macro"
        case .canola: "sun.max"
        case .hydrangea: "leaf"
        case .lotus: "drop"
        case .silverGrass: "wind"
        case .autumnLeaves: "leaf.fill"
        case .snowscape: "snowflake"
        case .nightView: "building.2"
        case .milkyWay: "sparkles"
        case .sunrise: "sunrise"
        case .sunset: "sunset"
        case .seaOfClouds: "cloud.fog"
        }
    }
}

extension SkyCondition {
    var symbolName: String {
        switch self {
        case .clear: "sun.max"
        case .partlyCloudy: "cloud.sun"
        case .cloudy: "cloud"
        case .fog: "cloud.fog"
        case .rain: "cloud.rain"
        case .snow: "cloud.snow"
        case .unknown: "questionmark.circle"
        }
    }
}

extension SourceKind {
    var symbolName: String {
        switch self {
        case .naverBlog, .daumBlog: "text.book.closed"
        case .naverCafe, .daumCafe: "person.3"
        }
    }
}

extension Date {
    var shortTime: String { formatted(date: .omitted, time: .shortened) }
}
