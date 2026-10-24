import GardenCore

/// 위치/지역명 제공. Preview·테스트에서는 고정값 구현을 주입한다.
@MainActor
protocol LocationProviding: AnyObject {
    func currentCoordinate() async -> Coordinate?
    func regionName(for coordinate: Coordinate) async -> String?
}

/// Preview용 고정 위치.
@MainActor
final class FixedLocationProvider: LocationProviding {
    let coordinate: Coordinate?
    let region: String?
    init(coordinate: Coordinate? = .seoul, region: String? = "서울") {
        self.coordinate = coordinate
        self.region = region
    }
    func currentCoordinate() async -> Coordinate? { coordinate }
    func regionName(for coordinate: Coordinate) async -> String? { region }
}
