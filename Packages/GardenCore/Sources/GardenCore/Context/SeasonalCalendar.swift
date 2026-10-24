import Foundation

/// 계절/날짜 계산 유틸리티 (연도와 무관한 "같은 시기" 비교 포함).
public struct SeasonalCalendar: Sendable {
    public var calendar: Calendar

    public init(timeZone: TimeZone = .seoul) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        self.calendar = calendar
    }

    public func season(of date: Date) -> Season {
        Season(month: calendar.component(.month, from: date))
    }

    public func dayOfYear(_ date: Date) -> Int {
        calendar.ordinality(of: .day, in: .year, for: date) ?? 1
    }

    /// 연도를 무시한 날짜 간 원형 거리 (0...183일).
    public func circularDayDistance(_ a: Date, _ b: Date) -> Int {
        let diff = abs(dayOfYear(a) - dayOfYear(b))
        return min(diff, 365 - diff)
    }
}
