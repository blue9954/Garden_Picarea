import Foundation
import Testing
@testable import GardenCore

@Suite("Scorer")
struct ScorerTests {
    let scorer = Scorer()
    let now = kst(2025, 6, 20, 18, 0)

    @Test func communityGrowsWithMentionsAndDiversity() {
        let few = [post("a", date: now)]
        let many = (0..<5).map { _ in post("a", date: now) }
        let diverse = [post("a", source: .naverBlog, date: now), post("b", source: .daumCafe, date: now)]
        let sameSource = [post("a", source: .naverBlog, date: now), post("b", source: .naverBlog, date: now)]
        #expect(scorer.community(posts: many, maxMentions: 5, activeSourceCount: 2, now: now)
            > scorer.community(posts: few, maxMentions: 5, activeSourceCount: 2, now: now))
        #expect(scorer.community(posts: diverse, maxMentions: 5, activeSourceCount: 2, now: now)
            > scorer.community(posts: sameSource, maxMentions: 5, activeSourceCount: 2, now: now))
        #expect(scorer.community(posts: [], maxMentions: 5, activeSourceCount: 2, now: now) == 0)
    }

    @Test func recencyHalvesAfterHalfLife() {
        let old = [post("a", date: now.addingTimeInterval(-365 * 86_400))]
        #expect(abs(scorer.recency(posts: old, now: now) - 0.5) < 0.01)
        #expect(scorer.recency(posts: [post("undated")], now: now) == 0.5)
    }

    @Test func seasonalRatioIgnoresYear() {
        let posts = [
            post("a", date: kst(2022, 6, 25)), // 같은 시기
            post("b", date: kst(2024, 6, 10)), // 같은 시기
            post("c", date: kst(2024, 12, 1)), // 다른 시기
            post("d"),                          // 날짜 없음 → 분모 제외
        ]
        #expect(abs(scorer.seasonalMentionRatio(posts: posts, now: now) - 2.0 / 3.0) < 1e-9)
    }

    @Test func themeSeasonMatch() {
        #expect(scorer.themeSeasonMatch(themes: [.hydrangea], now: now) == 1.0)
        #expect(scorer.themeSeasonMatch(themes: [.autumnLeaves], now: now) == 0.1)
        #expect(scorer.themeSeasonMatch(themes: [.sunset], now: now) == 0.8)
        #expect(scorer.themeSeasonMatch(themes: [], now: now) == 0.5)
    }

    @Test func weatherDependsOnTheme() {
        #expect(scorer.weather(themes: [.milkyWay], sky: .clear) == 1.0)
        #expect(scorer.weather(themes: [.milkyWay], sky: .rain) < 0.1)
        #expect(scorer.weather(themes: [.seaOfClouds], sky: .fog) == 1.0)
        #expect(scorer.weather(themes: [.hydrangea], sky: .unknown) == 0.5)
    }

    @Test func milkyWayPrefersDeepNight() {
        let midnight = kst(2025, 6, 21, 0, 30)
        let noon = kst(2025, 6, 20, 12, 0)
        func score(_ date: Date) -> Double {
            let sun = SolarCalculator.sunTimes(on: date, at: .seoul)
            return scorer.time(themes: [.milkyWay], now: date, sun: sun,
                               elevation: SolarCalculator.elevation(at: date, coordinate: .seoul))
        }
        #expect(score(midnight) == 1.0)
        #expect(score(noon) < 0.7)
    }

    @Test func sunsetScoreRisesAsGoldenHourApproaches() {
        let sun = SolarCalculator.sunTimes(on: now, at: .seoul)
        let golden = sun.goldenHourEvening!
        func score(_ date: Date) -> Double {
            scorer.time(themes: [.sunset], now: date, sun: sun, elevation: SolarCalculator.elevation(at: date, coordinate: .seoul))
        }
        #expect(score(golden.start.addingTimeInterval(60)) == 1.0)
        #expect(score(golden.start.addingTimeInterval(-3600)) > score(golden.start.addingTimeInterval(-6 * 3600)))
    }

    @Test func totalIsWeightedAverageAndClamped() {
        let breakdown = scorer.total(community: 1, season: 0, weather: 0, time: 0)
        #expect(abs(breakdown.total - 0.5) < 1e-9)
        let zeroWeights = Scorer(weights: ScoringWeights(community: 0, season: 0, weather: 0, time: 0))
        #expect(zeroWeights.total(community: 1, season: 1, weather: 1, time: 1).total == 0)
        #expect(scorer.total(community: .nan, season: 1, weather: 1, time: 1).total == 0)
    }
}
