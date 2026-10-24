import Foundation

/// 날씨 추상화. iOS 앱에서는 WeatherKit 구현을, 테스트에서는 고정값 구현을 주입한다.
public protocol WeatherProvider: Sendable {
    func sky(at coordinate: Coordinate, date: Date) async throws -> SkyCondition
}

/// 고정값 날씨 (테스트·SwiftUI Preview·키 미설정 시 사용).
public struct StaticWeatherProvider: WeatherProvider {
    public var condition: SkyCondition
    public init(_ condition: SkyCondition) { self.condition = condition }
    public func sky(at coordinate: Coordinate, date: Date) async throws -> SkyCondition { condition }
}
