import Foundation

/// SNS/커뮤니티 검색 소스.
public protocol CommunitySearchProvider: Sendable {
    /// 로그·에러 표시에 쓰는 이름.
    var name: String { get }
    var source: SourceKind { get }
    func search(_ query: String, limit: Int) async throws -> [CommunityPost]
}

/// 추출 후보를 실제 장소로 검증하고 좌표를 얻는다.
public protocol PlaceVerifier: Sendable {
    func verify(_ candidate: SpotCandidate, regionHint: String?) async throws -> VerifiedPlace?
}

enum DateParsing {
    /// 네이버 블로그 `postdate` (yyyyMMdd, KST).
    static func compactDate(_ string: String?, timeZone: TimeZone = .seoul) -> Date? {
        guard let string, string.count == 8, let value = Int(string) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = DateComponents(year: value / 10_000, month: (value / 100) % 100, day: value % 100, hour: 12)
        guard let month = components.month, (1...12).contains(month),
              let day = components.day, (1...31).contains(day) else { return nil }
        return calendar.date(from: components)
    }

    /// 카카오 `datetime` (ISO 8601, 밀리초 포함 가능).
    static func iso8601(_ string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        if let date = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(string) { return date }
        return try? Date.ISO8601FormatStyle().parse(string)
    }
}

extension URLComponents {
    static func build(_ base: String, _ items: [(String, String)], provider: String) throws -> URL {
        guard var components = URLComponents(string: base) else {
            throw GardenError.invalidRequest(provider: provider, message: "bad base URL")
        }
        components.queryItems = items.map { URLQueryItem(name: $0.0, value: $0.1) }
        // URLComponents는 '+'를 인코딩하지 않아 서버가 공백으로 해석할 수 있다.
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        guard let url = components.url else {
            throw GardenError.invalidRequest(provider: provider, message: "bad query")
        }
        return url
    }
}
