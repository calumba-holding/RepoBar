import Foundation

/// Simple in-memory ETag cache keyed by URL string.
actor ETagCache {
    private static let defaultMaxEntries = 512

    private let maxEntries: Int
    private var store: [String: (etag: String, data: Data)] = [:]
    private var entryOrder: [String] = []
    private var rateLimitedUntil: Date?

    init(maxEntries: Int = ETagCache.defaultMaxEntries) {
        self.maxEntries = max(0, maxEntries)
    }

    func cached(for url: URL) -> (etag: String, data: Data)? {
        let key = url.absoluteString
        guard let cached = self.store[key] else { return nil }
        self.touch(key)
        return cached
    }

    func save(url: URL, etag: String?, data: Data) {
        guard let etag else { return }
        guard self.maxEntries > 0 else { return }
        let key = url.absoluteString
        self.store[key] = (etag, data)
        self.touch(key)
        self.evictIfNeeded()
    }

    func setRateLimitReset(date: Date) {
        self.rateLimitedUntil = date
    }

    func rateLimitUntil(now: Date = Date()) -> Date? {
        guard let until = self.rateLimitedUntil else { return nil }
        if until <= now {
            self.rateLimitedUntil = nil
            return nil
        }
        return until
    }

    func isRateLimited(now: Date = Date()) -> Bool {
        guard let until = self.rateLimitUntil(now: now) else { return false }
        return until > now
    }

    func clear() {
        self.store.removeAll()
        self.entryOrder.removeAll()
        self.rateLimitedUntil = nil
    }

    func count() -> Int {
        self.store.count
    }

    private func touch(_ key: String) {
        self.entryOrder.removeAll { $0 == key }
        self.entryOrder.append(key)
    }

    private func evictIfNeeded() {
        while self.store.count > self.maxEntries, let oldest = self.entryOrder.first {
            self.entryOrder.removeFirst()
            self.store[oldest] = nil
        }
    }
}
