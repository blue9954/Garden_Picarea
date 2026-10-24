import Foundation

/// 위경도 좌표. CoreLocation에 의존하지 않아 Linux에서도 테스트 가능하다.
public struct Coordinate: Hashable, Sendable, Codable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    public var isValid: Bool {
        latitude.isFinite && longitude.isFinite
            && (-90...90).contains(latitude) && (-180...180).contains(longitude)
    }

    /// 하버사인 거리(미터).
    public func distance(to other: Coordinate) -> Double {
        let r = 6_371_000.0
        let dLat = (other.latitude - latitude) * .pi / 180
        let dLon = (other.longitude - longitude) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(latitude * .pi / 180) * cos(other.latitude * .pi / 180) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * r * atan2(sqrt(a), sqrt(1 - a))
    }

    /// 캐시 키용 반올림 좌표 (기본 0.1° ≈ 11km).
    public func rounded(step: Double = 0.1) -> Coordinate {
        Coordinate(latitude: (latitude / step).rounded() * step,
                   longitude: (longitude / step).rounded() * step)
    }

    /// 위치 권한이 없을 때 사용하는 기본 좌표 (서울시청).
    public static let seoul = Coordinate(latitude: 37.5665, longitude: 126.9780)
}
