import Foundation

/// TTL 기반 메모리 캐시. API 쿼터 절약용.
public actor ResponseCache<Value: Sendable> {
    private var storage: [String: (expires: Date, value: Value)] = [:]
    private let ttl: TimeInterval
    private let maxEntries: Int
    private let now: @Sendable () -> Date

    public init(ttl: TimeInterval = 30 * 60, maxEntries: Int = 200, now: @escaping @Sendable () -> Date = Date.init) {
        self.ttl = ttl
        self.maxEntries = maxEntries
        self.now = now
    }

    public func value(for key: String) -> Value? {
        guard let entry = storage[key] else { return nil }
        if entry.expires <= now() {
            storage[key] = nil
            return nil
        }
        return entry.value
    }

    public func insert(_ value: Value, for key: String) {
        if storage.count >= maxEntries {
            // 가장 먼저 만료될 항목부터 제거
            if let oldest = storage.min(by: { $0.value.expires < $1.value.expires })?.key { storage[oldest] = nil }
        }
        storage[key] = (now().addingTimeInterval(ttl), value)
    }

    public func removeAll() { storage.removeAll() }
}
