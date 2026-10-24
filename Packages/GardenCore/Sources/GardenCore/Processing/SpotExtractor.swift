import Foundation

/// 게시글에서 추출한 장소 후보 (아직 실존 검증 전).
public struct SpotCandidate: Hashable, Sendable {
    /// 비교 키 (공백 제거·소문자).
    public var key: String
    /// 가장 많이 쓰인 표기.
    public var name: String
    /// 이 후보를 언급한 게시글 (게시글당 1회).
    public var posts: [CommunityPost]
    /// 후보 앞에 붙어 있던 지역명 빈도 (예: "제주새별오름" → 제주).
    public var regionHints: [String: Int]

    public var mentionCount: Int { posts.count }
    public var dominantRegion: String? {
        regionHints.max { $0.value == $1.value ? $0.key > $1.key : $0.value < $1.value }?.key
    }
}

/// 규칙 기반 한국어 장소명 추출기.
/// 정확도보다 재현율을 우선하고, 거짓 양성은 PlaceVerifier(카카오 로컬)가 걸러낸다.
public struct SpotExtractor: Sendable {
    /// 장소명 끝에 오는 접미사. 정규식 교대(alternation)는 앞에서부터 매칭되므로 긴 것을 먼저 둔다.
    public static let placeSuffixes: [String] = [
        "해수욕장", "해안도로", "한옥마을", "벽화마을", "생태공원", "수목원", "식물원", "전망대", "저수지",
        "둘레길", "해변", "해안", "공원", "정원", "오름", "폭포", "호수", "대교", "다리", "성당", "사찰",
        "숲길", "마을", "포구", "계곡", "산성", "고개", "등대", "습지", "농원", "농장", "목장", "갯벌",
        "궁", "숲", "섬", "항", "봉", "산", "사", "길", "역", "성", "댐",
    ]

    /// 후보 키에 포함되면 버리는 일반어.
    public static let genericFragments: [String] = [
        "출사", "사진", "여행", "추천", "명소", "후기", "맛집", "카페", "스타그램", "그램", "블로그", "일상",
        "데이트", "가볼만한", "투어", "코스", "나들이", "포토", "스냅", "리뷰", "정보", "풍경", "핫플", "드라이브",
        "카메라", "렌즈", "주차", "입장료", "국립공원", "도립공원", "근린공원", "테마공원", "가는길", "오는길",
        "산책길", "출근길", "퇴근길", "꽃길", "지난", "이번", "근처", "주변", "동네", "인근", "우리",
        "축제", "순서", "베스트", "포인트", "만개", "활짝", "가득", "소식",
    ]

    /// 단독으로 쓰이면 장소가 아닌 단어 (정확히 일치할 때만 제거).
    public static let stopwords: Set<String> = [
        "최고", "인생", "예쁜", "이쁜", "아름다운", "올해", "작년", "요즘", "오늘", "어제", "주말", "새벽", "오후",
        "아침", "저녁", "역시", "정말", "진짜", "그리고", "여기", "거기", "봄", "여름", "가을", "겨울", "동백",
        "맑음", "흐림", "구름", "하늘", "바다", "노란", "파란", "하얀", "분홍", "보라",
    ]

    /// 조사 (긴 것 먼저). 테마어 앞 단어/나열 항목의 꼬리 정리에 사용.
    static let particles = ["에서", "에는", "에도", "으로", "까지", "부터", "에", "의", "은", "는", "이", "가", "을", "를", "도", "로", "과", "와", "만"]

    /// 이 단어 바로 앞의 토큰은 장소명일 가능성이 높다 ("혼인지 수국", "보롬왓 출사").
    static let anchorWords: [String] = Theme.allCases.flatMap(\.keywords) + ["출사", "사진", "명소", "포토존", "축제"]

    let minStemLength: Int
    let maxStemLength: Int
    private let suffixRegex: NSRegularExpression
    private let hashtagRegex: NSRegularExpression
    private let quotedRegex: NSRegularExpression
    private let anchorRegex: NSRegularExpression

    public init(minStemLength: Int = 2, maxStemLength: Int = 10) {
        self.minStemLength = minStemLength
        self.maxStemLength = maxStemLength
        let suffixes = Self.placeSuffixes.joined(separator: "|")
        // stem(한글/영문/숫자) + 선택적 공백 1개 + 접미사.
        // 접미사 뒤에는 조사(선택) + 단어 경계가 와야 한다. 이게 없으면 "…에서 사진"의 "사"처럼
        // 한 글자 접미사가 뒷말을 삼켜 진짜 장소명까지 소비해 버린다.
        let particles = "에서|에는|에도|에|의|은|는|이|가|을|를|도|으로|로|과|와|까지|부터|만|이다|입니다"
        // swiftlint:disable force_try — 정적 패턴이므로 컴파일 실패는 프로그래머 오류.
        suffixRegex = try! NSRegularExpression(
            pattern: "([가-힣A-Za-z0-9]{1,\(maxStemLength + 4)}) ?(\(suffixes))(?=(?:\(particles))?(?:[^가-힣A-Za-z0-9]|$))"
        )
        hashtagRegex = try! NSRegularExpression(pattern: "#([가-힣A-Za-z0-9_]{2,25})")
        quotedRegex = try! NSRegularExpression(pattern: "[\\[‘'\"“「『]([가-힣A-Za-z0-9 ]{2,15})[\\]’'\"”」』]")
        let anchors = Self.anchorWords.sorted { $0.count > $1.count }.joined(separator: "|")
        anchorRegex = try! NSRegularExpression(pattern: "(?<![가-힣A-Za-z0-9])([가-힣]{2,12}) (?:\(anchors))")
        // swiftlint:enable force_try
    }

    /// 한 게시글에서 후보 표기 목록 추출 (중복 제거, 지역 접두어 분리).
    public func candidates(in text: String, intent: SearchIntent? = nil) -> [(name: String, region: String?)] {
        var results: [(String, String?)] = []
        var seen = Set<String>()
        func add(_ raw: String) {
            guard let (name, region) = refine(raw, intent: intent) else { return }
            let key = TextNormalizer.key(name)
            if seen.insert(key).inserted { results.append((name, region)) }
        }
        let range = NSRange(text.startIndex..., in: text)
        for match in hashtagRegex.matches(in: text, range: range) {
            if let r = Range(match.range(at: 1), in: text) { add(String(text[r])) }
        }
        for match in quotedRegex.matches(in: text, range: range) {
            if let r = Range(match.range(at: 1), in: text) {
                let inner = String(text[r])
                // 괄호 안이 장소 접미사로 끝날 때만 인정 (말머리 "[제주 여행]" 등 배제)
                if Self.placeSuffixes.contains(where: { inner.hasSuffix($0) }) { add(inner) }
            }
        }
        for match in suffixRegex.matches(in: text, range: range) {
            guard let stemRange = Range(match.range(at: 1), in: text),
                  let suffixRange = Range(match.range(at: 2), in: text) else { continue }
            add(String(text[stemRange]) + String(text[suffixRange]))
        }
        for match in anchorRegex.matches(in: text, range: range) {
            guard let r = Range(match.range(at: 1), in: text) else { continue }
            let token = String(text[r])
            // "찍은 수국", "따라 수국"처럼 용언 활용형은 장소명이 아니다
            if Self.verbEndings.contains(where: { token.hasSuffix($0) }) { continue }
            add(Self.stripParticle(token))
        }
        for item in Self.listItems(in: text) { add(Self.stripParticle(item)) }
        return results
    }

    /// "보롬왓, 휴애리, 혼인지 순서로" 같은 3개 이상 나열의 각 항목 첫 단어.
    static func listItems(in text: String) -> [String] {
        text.components(separatedBy: CharacterSet(charactersIn: ".!?\n")).flatMap { sentence -> [String] in
            let parts = sentence.components(separatedBy: CharacterSet(charactersIn: ",·/"))
            guard parts.count >= 3 else { return [] }
            return parts.compactMap { part in
                part.split(separator: " ").first.map(String.init)
            }
        }
    }

    /// 테마어 앞 토큰에서 거르는 용언 활용 어미.
    static let verbEndings = ["은", "는", "던", "한", "된", "운", "른", "라", "고", "며", "서", "게", "니", "면", "요", "다", "죠", "든"]

    static func stripParticle(_ token: String) -> String {
        for particle in particles where token.hasSuffix(particle) && token.count - particle.count >= 2 {
            return String(token.dropLast(particle.count))
        }
        return token
    }

    /// 표기 정제: 공백 제거, 지역 접두어 분리, 일반어/테마어/지역명 단독 제거.
    func refine(_ raw: String, intent: SearchIntent?) -> (String, String?)? {
        var name = raw.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "_", with: "")
        guard name.unicodeScalars.contains(where: { (0xAC00...0xD7A3).contains($0.value) }) else { return nil }

        var region: String?
        if let prefix = QueryBuilder.regions.sorted(by: { $0.count > $1.count }).first(where: { name.hasPrefix($0) }) {
            let remainder = String(name.dropFirst(prefix.count))
            if stemLength(of: remainder) >= minStemLength {
                name = remainder
                region = prefix
            }
        }

        let key = TextNormalizer.key(name)
        if Self.genericFragments.contains(where: { key.contains($0) }) { return nil }
        if QueryBuilder.regions.contains(name) || Self.stopwords.contains(name) { return nil }
        let themeWords = Theme.allCases.flatMap(\.keywords)
        if themeWords.contains(name) { return nil }
        // "수국길", "벚꽃길"처럼 테마어 + 접미사는 일반 명사
        if let suffix = Self.placeSuffixes.first(where: { name.hasSuffix($0) }),
           themeWords.contains(String(name.dropLast(suffix.count))) { return nil }
        // "6월", "20일" 같은 날짜 표현
        if name.range(of: "^[0-9]+(월|일|년|시)", options: .regularExpression) != nil { return nil }
        if let intent, intent.raw.replacingOccurrences(of: " ", with: "") == name { return nil }
        guard (2...(maxStemLength + 6)).contains(name.count) else { return nil }
        if Self.placeSuffixes.contains(where: { name.hasSuffix($0) }), stemLength(of: name) < minStemLength {
            return nil
        }
        return (name, region)
    }

    /// 단어 경계 + (선택) 지역 접두어 + 이름 + (선택) 조사 + 경계.
    static func wordMatcher(for name: String) -> NSRegularExpression? {
        let regions = QueryBuilder.regions.sorted { $0.count > $1.count }.joined(separator: "|")
        let particles = Self.particles.joined(separator: "|")
        let escaped = NSRegularExpression.escapedPattern(for: name)
        return try? NSRegularExpression(
            pattern: "(?<![가-힣A-Za-z0-9])(\(regions))? ?\(escaped)(?=(?:\(particles))?(?:[^가-힣A-Za-z0-9]|$))"
        )
    }

    /// 접미사를 제외한 앞부분 길이. 접미사가 없으면 전체 길이.
    func stemLength(of name: String) -> Int {
        guard let suffix = Self.placeSuffixes.first(where: { name.hasSuffix($0) }) else { return name.count }
        return name.count - suffix.count
    }

    /// 게시글 묶음 → 후보 집계 (언급 많은 순).
    /// 1단계: 게시글별 패턴 추출로 시드 수집.
    /// 2단계: 시드 이름이 다른 게시글 본문에 단어로 등장하면 언급으로 전파 ("보롬왓에서 찍은…").
    public func extract(from posts: [CommunityPost], intent: SearchIntent? = nil) -> [SpotCandidate] {
        var buckets: [String: (forms: [String: Int], posts: [CommunityPost], regions: [String: Int])] = [:]
        var postKeys: [Set<String>] = Array(repeating: [], count: posts.count)
        func record(_ name: String, region: String?, postIndex: Int) {
            let key = TextNormalizer.key(name)
            guard postKeys[postIndex].insert(key).inserted else { return }
            var bucket = buckets[key] ?? ([:], [], [:])
            bucket.forms[name, default: 0] += 1
            bucket.posts.append(posts[postIndex])
            if let region { bucket.regions[region, default: 0] += 1 }
            buckets[key] = bucket
        }
        for (index, post) in posts.enumerated() {
            for (name, region) in candidates(in: post.fullText, intent: intent) {
                record(name, region: region, postIndex: index)
            }
        }
        let seeds = buckets.values.compactMap { $0.forms.max { $0.value < $1.value }?.key }
        for seed in seeds {
            guard let matcher = Self.wordMatcher(for: seed) else { continue }
            for (index, post) in posts.enumerated() where !postKeys[index].contains(TextNormalizer.key(seed)) {
                let text = post.fullText
                guard text.contains(seed) else { continue }
                if let match = matcher.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
                    let region = Range(match.range(at: 1), in: text).map { String(text[$0]) }
                    record(seed, region: region, postIndex: index)
                }
            }
        }
        return buckets.map { key, bucket in
            let name = bucket.forms.max { $0.value == $1.value ? $0.key > $1.key : $0.value < $1.value }!.key
            return SpotCandidate(key: key, name: name, posts: bucket.posts, regionHints: bucket.regions)
        }
        .sorted { $0.mentionCount == $1.mentionCount ? $0.key < $1.key : $0.mentionCount > $1.mentionCount }
    }
}
