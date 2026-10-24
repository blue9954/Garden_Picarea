import Foundation

/// 사용자 검색어를 해석해 커뮤니티 검색용 질의 목록을 만든다.
public struct SearchIntent: Hashable, Sendable {
    public var raw: String
    public var themes: Set<Theme>
    public var region: String?
    public var queries: [String]
}

public enum QueryBuilder {
    /// 지역 힌트로 인식할 주요 지명 (검증 질의 보강 및 후보 불용어로 사용).
    public static let regions: [String] = [
        "서울", "부산", "대구", "인천", "광주", "대전", "울산", "세종", "제주", "서귀포",
        "경기", "강원", "충북", "충남", "전북", "전남", "경북", "경남",
        "수원", "용인", "고양", "파주", "가평", "양평", "춘천", "강릉", "속초", "양양", "평창", "정선",
        "단양", "청주", "공주", "부여", "태안", "보령", "전주", "군산", "남원", "여수", "순천", "담양", "보성",
        "목포", "경주", "안동", "포항", "통영", "거제", "남해", "진주", "창원", "하동",
    ]

    static let photoSuffixes = ["출사", "출사지", "사진 명소", "포토스팟", "사진"]

    public static func intent(for rawQuery: String, maxQueries: Int = 2) -> SearchIntent {
        let query = rawQuery.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let themes = Theme.detect(in: query)
        let region = query.split(separator: " ").map(String.init).first { token in
            regions.contains { token.hasPrefix($0) }
        }
        guard !query.isEmpty else {
            return SearchIntent(raw: rawQuery, themes: [], region: nil, queries: [])
        }
        let alreadyPhotoQuery = photoSuffixes.contains { query.contains($0) }
        let queries = alreadyPhotoQuery
            ? [query]
            : Array(["\(query) 출사", "\(query) 사진 명소"].prefix(max(1, maxQueries)))
        return SearchIntent(raw: rawQuery, themes: themes, region: region, queries: queries)
    }
}
