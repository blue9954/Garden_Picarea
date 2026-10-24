import CoreLocation
import Foundation
import GardenCore
import WeatherKit

/// Apple WeatherKit → SkyCondition 변환.
/// App ID에 WeatherKit capability가 없으면 실패하며, 엔진은 날씨 점수를 중립값으로 처리한다.
struct WeatherKitProvider: WeatherProvider {
    func sky(at coordinate: Coordinate, date: Date) async throws -> SkyCondition {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let current = try await WeatherService.shared.weather(for: location, including: .current)
        return Self.map(current.condition)
    }

    static func map(_ condition: WeatherCondition) -> SkyCondition {
        switch condition {
        case .clear, .mostlyClear, .hot: .clear
        case .partlyCloudy: .partlyCloudy
        case .mostlyCloudy, .cloudy, .breezy, .windy: .cloudy
        case .foggy, .haze, .smoky, .blowingDust: .fog
        case .drizzle, .rain, .heavyRain, .sunShowers, .freezingDrizzle, .freezingRain, .hail,
             .isolatedThunderstorms, .scatteredThunderstorms, .thunderstorms, .strongStorms,
             .tropicalStorm, .hurricane:
            .rain
        case .flurries, .snow, .heavySnow, .sleet, .wintryMix, .blizzard, .blowingSnow, .sunFlurries, .frigid:
            .snow
        @unknown default:
            .unknown
        }
    }
}
