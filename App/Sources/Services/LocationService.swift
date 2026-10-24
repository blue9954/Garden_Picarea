import CoreLocation
import GardenCore

/// CLLocationManager 1회 위치 요청을 async로 감싼 서비스.
/// 권한 거부·실패 시 nil을 반환하고, 호출부는 서울 기본 좌표로 대체한다.
@MainActor
final class LocationService: NSObject, LocationProviding, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var pending: [CheckedContinuation<Coordinate?, Never>] = []

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func currentCoordinate() async -> Coordinate? {
        switch manager.authorizationStatus {
        case .denied, .restricted: return nil
        default: break
        }
        return await withCheckedContinuation { continuation in
            pending.append(continuation)
            guard pending.count == 1 else { return } // 진행 중인 요청에 합류
            if manager.authorizationStatus == .notDetermined {
                manager.requestWhenInUseAuthorization()
            } else {
                manager.requestLocation()
            }
        }
    }

    func regionName(for coordinate: Coordinate) async -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        // CLPlacemark는 Sendable이 아니므로 콜백 안에서 문자열만 꺼내 넘긴다 (Swift 6 strict concurrency)
        let geocoder = CLGeocoder()
        let names: [String] = await withCheckedContinuation { continuation in
            geocoder.reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "ko_KR")) { placemarks, _ in
                let placemark = placemarks?.first
                continuation.resume(returning: [placemark?.locality, placemark?.administrativeArea].compactMap { $0 })
            }
        }
        // "제주특별자치도"/"서귀포시" → QueryBuilder가 아는 지역 접두어로 축약
        for name in names {
            if let region = QueryBuilder.regions.first(where: { name.hasPrefix($0) }) { return region }
        }
        return names.first
    }

    private func finish(_ coordinate: Coordinate?) {
        let waiting = pending
        pending.removeAll()
        waiting.forEach { $0.resume(returning: coordinate) }
    }

    // MARK: CLLocationManagerDelegate (임의 스레드 → MainActor로 전달)

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            guard !self.pending.isEmpty else { return }
            switch status {
            case .authorizedWhenInUse, .authorizedAlways: self.manager.requestLocation()
            case .denied, .restricted: self.finish(nil)
            default: break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let coordinate = locations.last.map { Coordinate(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude) }
        Task { @MainActor in self.finish(coordinate) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.finish(nil) }
    }
}
