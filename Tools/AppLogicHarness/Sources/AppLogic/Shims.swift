import Foundation

import GardenCore

// Apple 전용 프레임워크(CoreLocation, WeatherKit) 구현을 대체하는 하네스용 스텁.
// 실제 구현: App/Sources/Services/LocationService.swift, WeatherKitProvider.swift

@MainActor
final class LocationService: LocationProviding {
    func currentCoordinate() async -> Coordinate? { nil }
    func regionName(for coordinate: Coordinate) async -> String? { nil }
}

struct WeatherKitProvider: WeatherProvider {
    func sky(at coordinate: Coordinate, date: Date) async throws -> SkyCondition { .unknown }
}
