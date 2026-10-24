import Foundation

/// 캐시 + 429 쿨다운(지수 백오프)을 씌운 Provider 데코레이터.
public struct ResilientProvider: CommunitySearchProvider {
    let base: any CommunitySearchProvider
    let cache: ResponseCache<[CommunityPost]>
    let gate: CooldownGate

    public init(_ base: any CommunitySearchProvider, cacheTTL: TimeInterval = 30 * 60,
                now: @escaping @Sendable () -> Date = Date.init) {
        self.base = base
        self.cache = ResponseCache(ttl: cacheTTL, now: now)
        self.gate = CooldownGate(now: now)
    }

    public var name: String { base.name }
    public var source: SourceKind { base.source }

    public func search(_ query: String, limit: Int) async throws -> [CommunityPost] {
        let key = "\(query)|\(limit)"
        if let cached = await cache.value(for: key) { return cached }
        if let until = await gate.blockedUntil() {
            throw GardenError.rateLimited(provider: name, retryAfter: until.timeIntervalSinceNow)
        }
        do {
            let posts = try await base.search(query, limit: limit)
            await gate.recordSuccess()
            await cache.insert(posts, for: key)
            return posts
        } catch let GardenError.rateLimited(provider, retryAfter) {
            await gate.recordRateLimit(retryAfter: retryAfter)
            throw GardenError.rateLimited(provider: provider, retryAfter: retryAfter)
        }
    }
}

actor CooldownGate {
    private var until: Date?
    private var consecutive = 0
    private let now: @Sendable () -> Date
    static let baseDelay: TimeInterval = 30
    static let maxDelay: TimeInterval = 10 * 60

    init(now: @escaping @Sendable () -> Date) { self.now = now }

    func blockedUntil() -> Date? {
        guard let until, until > now() else { return nil }
        return until
    }

    func recordSuccess() {
        consecutive = 0
        until = nil
    }

    func recordRateLimit(retryAfter: TimeInterval?) {
        consecutive += 1
        let backoff = min(Self.maxDelay, Self.baseDelay * pow(2, Double(consecutive - 1)))
        until = now().addingTimeInterval(max(retryAfter ?? 0, backoff))
    }
}
