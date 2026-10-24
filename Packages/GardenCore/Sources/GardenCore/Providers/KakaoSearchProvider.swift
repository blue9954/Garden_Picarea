import Foundation

/// 다음(카카오) 검색 API (블로그 / 카페). https://developers.kakao.com/docs/latest/ko/daum-search/dev-guide
public struct KakaoSearchProvider: CommunitySearchProvider {
    public enum Kind: String, Sendable { case blog, cafe }

    public let kind: Kind
    let restAPIKey: String
    let client: any HTTPClient
    static let baseURL = "https://dapi.kakao.com/v2/search/"
    static let maxSize = 50

    public init(kind: Kind, restAPIKey: String, client: any HTTPClient = URLSessionHTTPClient()) {
        self.kind = kind
        self.restAPIKey = restAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        self.client = client
    }

    public var name: String { source.koreanName }
    public var source: SourceKind { kind == .blog ? .daumBlog : .daumCafe }

    public func search(_ query: String, limit: Int) async throws -> [CommunityPost] {
        guard !restAPIKey.isEmpty else { throw GardenError.missingCredentials(provider: name) }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let size = min(max(limit, 1), Self.maxSize)
        let url = try URLComponents.build(Self.baseURL + kind.rawValue,
                                          [("query", trimmed), ("size", String(size)), ("sort", "accuracy")],
                                          provider: name)
        let request = HTTPRequest(url: url, headers: ["Authorization": "KakaoAK \(restAPIKey)"])
        let response = try await client.fetchJSON(KakaoSearchResponse.self, request: request, provider: name)
        return (response.documents ?? []).compactMap { doc in
            guard let link = doc.url, !link.isEmpty else { return nil }
            return CommunityPost(
                source: source,
                title: TextNormalizer.clean(doc.title ?? ""),
                snippet: TextNormalizer.clean(doc.contents ?? ""),
                url: link,
                author: doc.blogname ?? doc.cafename,
                publishedAt: DateParsing.iso8601(doc.datetime)
            )
        }
    }

    struct KakaoSearchResponse: Decodable {
        let documents: [Document]?
        struct Document: Decodable {
            let title: String?
            let contents: String?
            let url: String?
            let blogname: String?
            let cafename: String?
            let datetime: String?
        }
    }
}

/// 카카오 로컬 키워드 검색으로 장소 실존 검증. https://developers.kakao.com/docs/latest/ko/local/dev-guide
public struct KakaoPlaceVerifier: PlaceVerifier {
    let restAPIKey: String
    let client: any HTTPClient
    static let baseURL = "https://dapi.kakao.com/v2/local/search/keyword.json"
    static let providerName = "카카오 로컬"
    /// 출사지가 아닌 카테고리 (음식점, 편의점, 은행, 주유소, 주차장, 병원, 약국, 중개업소).
    static let excludedCategoryCodes: Set<String> = ["FD6", "CS2", "BK9", "OL7", "PK6", "HP8", "PM9", "AG2"]
    static let excludedNameFragments = ["주차장", "화장실", "매표소", "정류장", "편의점", "주유소", "식당"]

    public init(restAPIKey: String, client: any HTTPClient = URLSessionHTTPClient()) {
        self.restAPIKey = restAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        self.client = client
    }

    public func verify(_ candidate: SpotCandidate, regionHint: String?) async throws -> VerifiedPlace? {
        guard !restAPIKey.isEmpty else { throw GardenError.missingCredentials(provider: Self.providerName) }
        if let regionHint, !regionHint.isEmpty,
           let place = try await lookup(query: "\(regionHint) \(candidate.name)", candidateKey: candidate.key) {
            return place
        }
        return try await lookup(query: candidate.name, candidateKey: candidate.key)
    }

    func lookup(query: String, candidateKey: String) async throws -> VerifiedPlace? {
        let url = try URLComponents.build(Self.baseURL, [("query", query), ("size", "5")], provider: Self.providerName)
        let request = HTTPRequest(url: url, headers: ["Authorization": "KakaoAK \(restAPIKey)"])
        let response = try await client.fetchJSON(LocalResponse.self, request: request, provider: Self.providerName)
        return Self.bestMatch(in: response.documents ?? [], candidateKey: candidateKey)
    }

    /// 정확 일치(3) > 후보로 시작(2) > 포함(1). 동점이면 카카오 정확도 순서 유지.
    static func bestMatch(in documents: [LocalResponse.Document], candidateKey: String) -> VerifiedPlace? {
        var best: (score: Int, place: VerifiedPlace)?
        for doc in documents {
            guard let name = doc.place_name, let id = doc.id,
                  let lon = doc.x.flatMap(Double.init), let lat = doc.y.flatMap(Double.init) else { continue }
            let coordinate = Coordinate(latitude: lat, longitude: lon)
            guard coordinate.isValid else { continue }
            if let code = doc.category_group_code, excludedCategoryCodes.contains(code) { continue }
            if excludedNameFragments.contains(where: { name.contains($0) }) { continue }
            let key = TextNormalizer.key(name)
            let score: Int
            if key == candidateKey { score = 3 }
            else if key.hasPrefix(candidateKey) || key.hasSuffix(candidateKey) { score = 2 }
            else if key.contains(candidateKey) || (key.count >= 3 && candidateKey.contains(key)) { score = 1 }
            else { continue }
            // 부분 일치는 관광/자연 계열 장소일 때만 인정 ("최고" → "최고집 식당" 같은 오매칭 방지)
            if score < 3 && !isScenic(code: doc.category_group_code, category: doc.category_name) { continue }
            if best == nil || score > best!.score {
                let address = [doc.road_address_name, doc.address_name].compactMap { $0 }.first { !$0.isEmpty } ?? ""
                best = (score, VerifiedPlace(id: "kakao:\(id)", name: name, address: address,
                                             category: doc.category_name ?? "", coordinate: coordinate,
                                             placeURL: doc.place_url))
            }
        }
        return best?.place
    }

    static let scenicCategoryCodes: Set<String> = ["AT4", "CT1"] // 관광명소, 문화시설
    static let scenicCategoryWords = ["여행", "관광", "명소", "공원", "자연", "산", "해수욕장", "수목원", "식물원", "사찰", "성당"]

    static func isScenic(code: String?, category: String?) -> Bool {
        if let code, scenicCategoryCodes.contains(code) { return true }
        guard let category else { return false }
        return scenicCategoryWords.contains { category.contains($0) }
    }

    // swiftlint:disable identifier_name — 카카오 응답 키 그대로 사용
    struct LocalResponse: Decodable {
        let documents: [Document]?
        struct Document: Decodable {
            let id: String?
            let place_name: String?
            let category_name: String?
            let category_group_code: String?
            let address_name: String?
            let road_address_name: String?
            let x: String?
            let y: String?
            let place_url: String?
        }
    }
    // swiftlint:enable identifier_name
}
