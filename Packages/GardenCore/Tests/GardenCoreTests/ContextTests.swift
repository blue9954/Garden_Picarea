import Foundation
import Testing
@testable import GardenCore

/// 참조값: astral 3.x (Python, 독립 구현)으로 계산한 서울시청 좌표 KST 시각.
@Suite("SolarCalculator")
struct SolarCalculatorTests {
    static let tolerance: TimeInterval = 90

    struct Reference: Sendable, CustomTestStringConvertible {
        let date: (Int, Int, Int)
        let sunrise: (Int, Int, Int)
        let sunset: (Int, Int, Int)
        let goldenEvening: ((Int, Int, Int), (Int, Int, Int))
        var testDescription: String { "\(date)" }
    }

    static let references = [
        Reference(date: (2024, 6, 21), sunrise: (5, 11, 19), sunset: (19, 56, 32), goldenEvening: ((19, 18, 30), (20, 16, 13))),
        Reference(date: (2024, 12, 21), sunrise: (7, 43, 27), sunset: (17, 17, 0), goldenEvening: ((16, 37, 10), (17, 35, 50))),
        Reference(date: (2025, 3, 20), sunrise: (6, 36, 12), sunset: (18, 43, 30), goldenEvening: ((18, 9, 53), (19, 0, 8))),
    ]

    func at(_ d: (Int, Int, Int), _ t: (Int, Int, Int)) -> Date { kst(d.0, d.1, d.2, t.0, t.1, t.2) }

    @Test(arguments: references)
    func matchesIndependentReference(_ ref: Reference) throws {
        let sun = SolarCalculator.sunTimes(on: kst(ref.date.0, ref.date.1, ref.date.2), at: .seoul)
        let sunrise = try #require(sun.sunrise)
        let sunset = try #require(sun.sunset)
        let golden = try #require(sun.goldenHourEvening)
        #expect(abs(sunrise.timeIntervalSince(at(ref.date, ref.sunrise))) < Self.tolerance)
        #expect(abs(sunset.timeIntervalSince(at(ref.date, ref.sunset))) < Self.tolerance)
        #expect(abs(golden.start.timeIntervalSince(at(ref.date, ref.goldenEvening.0))) < Self.tolerance)
        #expect(abs(golden.end.timeIntervalSince(at(ref.date, ref.goldenEvening.1))) < Self.tolerance)
    }

    @Test func eventsAreOrdered() throws {
        let sun = SolarCalculator.sunTimes(on: kst(2025, 10, 24), at: .seoul)
        let blueAM = try #require(sun.blueHourMorning), goldenAM = try #require(sun.goldenHourMorning)
        let goldenPM = try #require(sun.goldenHourEvening), bluePM = try #require(sun.blueHourEvening)
        #expect(blueAM.end == goldenAM.start)
        #expect(goldenAM.end < sun.solarNoon && sun.solarNoon < goldenPM.start)
        #expect(goldenPM.end == bluePM.start)
    }

    @Test func midnightLocalTimeStillResolvesSameLocalDay() throws {
        // KST 00:30은 UTC로 전날 15:30 — 전날 일출을 반환하면 안 된다.
        let sun = SolarCalculator.sunTimes(on: kst(2024, 6, 21, 0, 30), at: .seoul)
        let sunrise = try #require(sun.sunrise)
        #expect(abs(sunrise.timeIntervalSince(kst(2024, 6, 21, 5, 11, 19))) < Self.tolerance)
    }

    @Test func polarDayHasNoSunset() {
        let tromso = Coordinate(latitude: 69.65, longitude: 18.96)
        let sun = SolarCalculator.sunTimes(on: kst(2024, 6, 21), at: tromso, timeZone: TimeZone(identifier: "Europe/Oslo")!)
        #expect(sun.sunrise == nil && sun.sunset == nil)
    }

    @Test func elevationAtSolarNoonMatchesGeometry() {
        let sun = SolarCalculator.sunTimes(on: kst(2024, 6, 21), at: .seoul)
        let elevation = SolarCalculator.elevation(at: sun.solarNoon, coordinate: .seoul)
        #expect(abs(elevation - (90 - 37.5665 + 23.44)) < 0.3)
        #expect(SolarCalculator.elevation(at: kst(2024, 6, 21, 0, 0), coordinate: .seoul) < -20)
    }
}

@Suite("Season")
struct SeasonTests {
    @Test(arguments: [(3, Season.spring), (5, .spring), (6, .summer), (9, .autumn), (11, .autumn), (12, .winter), (2, .winter)])
    func monthMapping(month: Int, expected: Season) {
        #expect(Season(month: month) == expected)
    }

    @Test func circularDistanceWrapsAroundNewYear() {
        let calendar = SeasonalCalendar()
        #expect(calendar.circularDayDistance(kst(2024, 12, 31), kst(2025, 1, 1)) <= 1)
        #expect(calendar.circularDayDistance(kst(2021, 6, 20), kst(2025, 6, 20)) <= 1)
    }

    @Test func themeDetection() {
        #expect(Theme.detect(in: "남산 야경과 노을") == [.nightView, .sunset])
        #expect(Theme.detect(in: "그냥 산책").isEmpty)
    }
}
