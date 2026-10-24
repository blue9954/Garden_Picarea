import Foundation

public struct ScoringWeights: Hashable, Sendable, Codable {
    public var community: Double
    public var season: Double
    public var weather: Double
    public var time: Double

    public init(community: Double = 0.50, season: Double = 0.25, weather: Double = 0.15, time: Double = 0.10) {
        self.community = community
        self.season = season
        self.weather = weather
        self.time = time
    }

    public static let standard = ScoringWeights()
    /// "지금 당장 나가기" 프리셋: 날씨·시간 비중 ↑
    public static let rightNow = ScoringWeights(community: 0.35, season: 0.2, weather: 0.25, time: 0.2)
}

/// 명세서 3.1의 점수 공식 구현. 모든 하위 점수는 0~1.
public struct Scorer: Sendable {
    public var weights: ScoringWeights
    public var calendar: SeasonalCalendar
    /// 같은 시기로 보는 원형 날짜 거리.
    public var seasonalWindowDays = 30
    public var recencyHalfLifeDays = 365.0
    static let neutral = 0.5

    public init(weights: ScoringWeights = .standard, calendar: SeasonalCalendar = SeasonalCalendar()) {
        self.weights = weights
        self.calendar = calendar
    }

    // MARK: Community

    public func community(posts: [CommunityPost], maxMentions: Int, activeSourceCount: Int, now: Date) -> Double {
        guard !posts.isEmpty else { return 0 }
        let volume = log(1 + Double(posts.count)) / log(1 + Double(max(maxMentions, posts.count, 1)))
        let diversity = Double(Set(posts.map(\.source)).count) / Double(max(activeSourceCount, 1))
        return clamp(0.6 * volume + 0.25 * min(diversity, 1) + 0.15 * recency(posts: posts, now: now))
    }

    public func recency(posts: [CommunityPost], now: Date) -> Double {
        let ages = posts.compactMap(\.publishedAt).map { max(0, now.timeIntervalSince($0) / 86_400) }
        guard !ages.isEmpty else { return Self.neutral }
        let decay = ages.map { exp(-$0 * log(2.0) / recencyHalfLifeDays) }
        return decay.reduce(0, +) / Double(decay.count)
    }

    // MARK: Season

    public func season(posts: [CommunityPost], themes: Set<Theme>, now: Date) -> Double {
        clamp(0.6 * seasonalMentionRatio(posts: posts, now: now) + 0.4 * themeSeasonMatch(themes: themes, now: now))
    }

    /// 연도 무관, 오늘 ±window일 안에 작성된 언급 비율.
    public func seasonalMentionRatio(posts: [CommunityPost], now: Date) -> Double {
        let dated = posts.compactMap(\.publishedAt)
        guard !dated.isEmpty else { return Self.neutral }
        let inWindow = dated.filter { calendar.circularDayDistance($0, now) <= seasonalWindowDays }.count
        return Double(inWindow) / Double(dated.count)
    }

    public func themeSeasonMatch(themes: Set<Theme>, now: Date) -> Double {
        guard !themes.isEmpty else { return Self.neutral }
        let current = calendar.season(of: now)
        return themes.map { theme in
            if theme.seasons.isEmpty { return 0.8 }
            return theme.seasons.contains(current) ? 1.0 : 0.1
        }.max() ?? Self.neutral
    }

    // MARK: Weather

    public func weather(themes: Set<Theme>, sky: SkyCondition) -> Double {
        guard sky != .unknown else { return Self.neutral }
        guard !themes.isEmpty else {
            switch sky {
            case .partlyCloudy: return 1.0
            case .clear: return 0.9
            case .cloudy, .fog, .snow: return 0.6
            case .rain: return 0.3
            case .unknown: return Self.neutral
            }
        }
        return themes.map { $0.weatherFitness(sky) }.max() ?? Self.neutral
    }

    // MARK: Time

    public func time(themes: Set<Theme>, now: Date, sun: SunTimes, elevation: Double) -> Double {
        let phase = SunPhase(elevation: elevation, now: now, sun: sun)
        guard !themes.isEmpty else {
            switch phase {
            case .golden: return 1.0
            case .blue: return 0.9
            case .day: return 0.6
            case .night: return 0.4
            }
        }
        return themes.map { theme -> Double in
            switch theme.timePreference {
            case .daylight:
                switch phase {
                case .golden: return 1.0
                case .day: return 0.85
                case .blue: return 0.5
                case .night: return 0.25
                }
            case .night:
                switch phase {
                case .night: return 1.0
                case .blue: return theme == .milkyWay ? 0.6 : 0.95
                default: return proximity(to: sun.blueHourEvening?.start, from: now)
                }
            case .morningGolden:
                if sun.goldenHourMorning?.contains(now) == true || sun.blueHourMorning?.contains(now) == true { return 1.0 }
                return proximity(to: sun.goldenHourMorning?.start ?? sun.sunrise, from: now)
            case .eveningGolden:
                if sun.goldenHourEvening?.contains(now) == true { return 1.0 }
                return proximity(to: sun.goldenHourEvening?.start ?? sun.sunset, from: now)
            }
        }.max() ?? Self.neutral
    }

    /// 다음 이벤트까지 남은 시간이 짧을수록 높음 (12시간 이상이면 0.2). 이미 지났으면 내일 같은 시각으로 본다.
    func proximity(to event: Date?, from now: Date) -> Double {
        guard var event else { return Self.neutral }
        while event < now { event = event.addingTimeInterval(86_400) }
        let hours = event.timeIntervalSince(now) / 3600
        return max(0.2, 1 - hours / 12)
    }

    // MARK: Total

    public func total(community: Double, season: Double, weather: Double, time: Double) -> ScoreBreakdown {
        let sum = weights.community + weights.season + weights.weather + weights.time
        let w = sum > 0 ? sum : 1
        let total = (weights.community * community + weights.season * season
            + weights.weather * weather + weights.time * time) / w
        return ScoreBreakdown(community: community, season: season, weather: weather, time: time, total: clamp(total))
    }

    func clamp(_ v: Double) -> Double { v.isFinite ? min(1, max(0, v)) : 0 }
}

/// 현재 태양 위상.
public enum SunPhase: Sendable, Equatable {
    case day, golden, blue, night

    public init(elevation: Double, now: Date, sun: SunTimes) {
        if sun.goldenHourMorning?.contains(now) == true || sun.goldenHourEvening?.contains(now) == true {
            self = .golden
        } else if sun.blueHourMorning?.contains(now) == true || sun.blueHourEvening?.contains(now) == true {
            self = .blue
        } else if elevation >= 6 {
            self = .day
        } else if elevation >= -4 {
            self = .golden
        } else if elevation >= -6 {
            self = .blue
        } else {
            self = .night
        }
    }
}
