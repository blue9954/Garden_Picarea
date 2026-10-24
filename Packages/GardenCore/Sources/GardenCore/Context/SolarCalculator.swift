import Foundation

/// 하루의 태양 이벤트. 극지방 백야/극야 등으로 계산이 불가능한 항목은 nil.
public struct SunTimes: Hashable, Sendable {
    public var sunrise: Date?
    public var sunset: Date?
    public var solarNoon: Date
    /// 태양 고도 -6°→-4° (상승)
    public var blueHourMorning: DateInterval?
    /// 태양 고도 -4°→+6° (상승)
    public var goldenHourMorning: DateInterval?
    /// 태양 고도 +6°→-4° (하강)
    public var goldenHourEvening: DateInterval?
    /// 태양 고도 -4°→-6° (하강)
    public var blueHourEvening: DateInterval?
}

/// NOAA 태양 위치 알고리즘 기반 계산기 (오차 ~1분, 위도 ±72° 이내).
/// 네트워크/API 키 없이 기기에서 바로 골든아워를 계산하기 위해 사용한다.
public enum SolarCalculator {
    static let refractionAltitude = -0.833 // 대기굴절 + 태양 반지름 보정

    /// `date`가 속한 `timeZone` 기준 날짜의 태양 이벤트.
    public static func sunTimes(on date: Date, at coordinate: Coordinate,
                                timeZone: TimeZone = .seoul) -> SunTimes {
        let dayStartUTC = utcMidnight(ofLocalDayContaining: date, timeZone: timeZone)
        func event(_ altitude: Double, rising: Bool) -> Date? {
            eventTime(dayStartUTC: dayStartUTC, coordinate: coordinate, altitude: altitude, rising: rising)
        }
        func interval(_ start: Date?, _ end: Date?) -> DateInterval? {
            guard let start, let end, end > start else { return nil }
            return DateInterval(start: start, end: end)
        }
        let noonMinutes = solarNoonMinutes(dayStartUTC: dayStartUTC, longitude: coordinate.longitude)
        return SunTimes(
            sunrise: event(refractionAltitude, rising: true),
            sunset: event(refractionAltitude, rising: false),
            solarNoon: dayStartUTC.addingTimeInterval(noonMinutes * 60),
            blueHourMorning: interval(event(-6, rising: true), event(-4, rising: true)),
            goldenHourMorning: interval(event(-4, rising: true), event(6, rising: true)),
            goldenHourEvening: interval(event(6, rising: false), event(-4, rising: false)),
            blueHourEvening: interval(event(-4, rising: false), event(-6, rising: false))
        )
    }

    /// 특정 시각의 태양 고도(도, 굴절 미보정).
    public static func elevation(at date: Date, coordinate: Coordinate) -> Double {
        let jd = julianDay(date)
        let s = SolarState(julianCentury: (jd - 2_451_545.0) / 36_525.0)
        let utcMinutes = date.timeIntervalSince1970.truncatingRemainder(dividingBy: 86_400) / 60
        var trueSolarTime = (utcMinutes + s.equationOfTime + 4 * coordinate.longitude)
            .truncatingRemainder(dividingBy: 1440)
        if trueSolarTime < 0 { trueSolarTime += 1440 }
        let hourAngle = (trueSolarTime / 4 - 180).radians
        let lat = coordinate.latitude.radians
        let cosZenith = sin(lat) * sin(s.declination) + cos(lat) * cos(s.declination) * cos(hourAngle)
        return 90 - acos(min(1, max(-1, cosZenith))).degrees
    }

    // MARK: - Internals

    struct SolarState {
        let declination: Double   // 라디안
        let equationOfTime: Double // 분

        init(julianCentury t: Double) {
            let l0 = (280.46646 + t * (36_000.76983 + t * 0.0003032)).truncatingRemainder(dividingBy: 360)
            let m = 357.52911 + t * (35_999.05029 - 0.0001537 * t)
            let e = 0.016708634 - t * (0.000042037 + 0.0000001267 * t)
            let c = sin(m.radians) * (1.914602 - t * (0.004817 + 0.000014 * t))
                + sin((2 * m).radians) * (0.019993 - 0.000101 * t)
                + sin((3 * m).radians) * 0.000289
            let omega = (125.04 - 1934.136 * t).radians
            let apparentLong = (l0 + c - 0.00569 - 0.00478 * sin(omega)).radians
            let meanObliq = 23 + (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60
            let obliq = (meanObliq + 0.00256 * cos(omega)).radians
            declination = asin(sin(obliq) * sin(apparentLong))
            let y = pow(tan(obliq / 2), 2)
            let l0r = l0.radians, mr = m.radians
            equationOfTime = 4 * (y * sin(2 * l0r) - 2 * e * sin(mr) + 4 * e * y * sin(mr) * cos(2 * l0r)
                - 0.5 * y * y * sin(4 * l0r) - 1.25 * e * e * sin(2 * mr)).degrees
        }
    }

    static func julianDay(_ date: Date) -> Double {
        date.timeIntervalSince1970 / 86_400 + 2_440_587.5
    }

    static func utcMidnight(ofLocalDayContaining date: Date, timeZone: TimeZone) -> Date {
        var local = Calendar(identifier: .gregorian)
        local.timeZone = timeZone
        let parts = local.dateComponents([.year, .month, .day], from: date)
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        return utc.date(from: parts) ?? date
    }

    static func solarNoonMinutes(dayStartUTC: Date, longitude: Double) -> Double {
        var minutes = 720 - 4 * longitude
        // 2회 반복으로 균시차를 정오 시각에 맞춰 보정
        for _ in 0..<2 {
            let jd = julianDay(dayStartUTC.addingTimeInterval(minutes * 60))
            let s = SolarState(julianCentury: (jd - 2_451_545.0) / 36_525.0)
            minutes = 720 - 4 * longitude - s.equationOfTime
        }
        return minutes
    }

    static func eventTime(dayStartUTC: Date, coordinate: Coordinate, altitude: Double, rising: Bool) -> Date? {
        let lat = coordinate.latitude.radians
        var minutes = solarNoonMinutes(dayStartUTC: dayStartUTC, longitude: coordinate.longitude)
        for _ in 0..<3 {
            let jd = julianDay(dayStartUTC.addingTimeInterval(minutes * 60))
            let s = SolarState(julianCentury: (jd - 2_451_545.0) / 36_525.0)
            let cosH = (sin(altitude.radians) - sin(lat) * sin(s.declination)) / (cos(lat) * cos(s.declination))
            guard (-1...1).contains(cosH) else { return nil } // 해당 고도에 도달하지 않음
            let hourAngle = acos(cosH).degrees
            let noon = 720 - 4 * coordinate.longitude - s.equationOfTime
            minutes = noon + (rising ? -4 : 4) * hourAngle
        }
        return dayStartUTC.addingTimeInterval(minutes * 60)
    }
}

extension Double {
    var radians: Double { self * .pi / 180 }
    var degrees: Double { self * 180 / .pi }
}

extension TimeZone {
    public static let seoul = TimeZone(identifier: "Asia/Seoul") ?? TimeZone(secondsFromGMT: 9 * 3600)!
}
