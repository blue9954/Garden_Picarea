import Foundation
import Testing
@testable import GardenCore

@Suite("TextNormalizer")
struct TextNormalizerTests {
    @Test func stripsBoldTagsAndEntities() {
        #expect(TextNormalizer.clean("제주 <b>수국</b> &amp; 혼인지") == "제주 수국 & 혼인지")
        #expect(TextNormalizer.clean("&quot;출사&quot; &#39;후기&#39; &#x41;") == "\"출사\" '후기' A")
    }

    @Test func removesTagsThatWereEntityEncoded() {
        #expect(TextNormalizer.clean("수국 &lt;b&gt;베스트&lt;/b&gt; 5") == "수국 베스트 5")
    }

    @Test func collapsesWhitespaceAndKeepsUnknownEntities() {
        #expect(TextNormalizer.clean("  a \n\t b  ") == "a b")
        #expect(TextNormalizer.clean("R&D &unknown; 5&6") == "R&D &unknown; 5&6")
    }

    @Test func keyIgnoresSpacingAndCase() {
        #expect(TextNormalizer.key("올림픽 공원") == TextNormalizer.key("올림픽공원"))
        #expect(TextNormalizer.key("Seoul Forest!") == "seoulforest")
    }
}

@Suite("QueryBuilder")
struct QueryBuilderTests {
    @Test func detectsThemeAndRegion() {
        let intent = QueryBuilder.intent(for: "  제주   수국 ")
        #expect(intent.themes == [.hydrangea])
        #expect(intent.region == "제주")
        #expect(intent.queries == ["제주 수국 출사", "제주 수국 사진 명소"])
    }

    @Test func doesNotDuplicatePhotoSuffix() {
        #expect(QueryBuilder.intent(for: "부산 야경 출사지").queries == ["부산 야경 출사지"])
    }

    @Test func emptyQueryProducesNoRequests() {
        #expect(QueryBuilder.intent(for: "   ").queries.isEmpty)
    }
}

@Suite("SpotExtractor")
struct SpotExtractorTests {
    let extractor = SpotExtractor()

    func names(_ text: String, intent: SearchIntent? = nil) -> [String] {
        extractor.candidates(in: text, intent: intent).map(\.name)
    }

    @Test func hashtagWithoutSuffixIsCandidate() {
        let found = names("제주 수국 보러 갔어요 #보롬왓 #제주수국 #출사")
        #expect(found == ["보롬왓"])
    }

    @Test func suffixMatchStopsBeforeParticle() {
        #expect(names("함덕해수욕장에서 사진 찍었어요") == ["함덕해수욕장"])
        #expect(names("새별오름에 다녀왔다. 한라산은 구름") == ["새별오름", "한라산"])
    }

    @Test func singleCharSuffixDoesNotSwallowNextWord() {
        // "…에서 사진"의 "사"를 접미사로 오인하면 안 된다 (회귀 테스트)
        #expect(!names("보롬왓에서 사진").contains { $0.hasSuffix("사") })
    }

    @Test func regionPrefixIsSplitIntoHint() {
        let found = extractor.candidates(in: "제주새별오름 일몰")
        #expect(found.first?.name == "새별오름")
        #expect(found.first?.region == "제주")
    }

    @Test func spacedNameIsJoined() {
        #expect(names("올림픽 공원 나홀로나무") == ["올림픽공원"])
    }

    @Test func genericPhrasesAreRejected() {
        #expect(names("가는 길에 들른 동네 공원, 산책길 추천").isEmpty)
        #expect(names("[제주 여행] 출사 후기").isEmpty)
        #expect(names("#제주여행 #수국 #sonya7m4").isEmpty)
    }

    @Test func extractCountsOncePerPostAndSortsByMentions() {
        let posts = [
            post("보롬왓 보롬왓 #보롬왓"),       // 한 글에서 여러 번 → 1회
            post("보롬왓에서 찍은 사진"),         // 시드 전파 (조사 허용)
            post("혼인지 수국 만개"),             // 테마어 앞 단어 → 시드
            post("혼인지로 가는 중"),             // 전파
            post("카멜리아힐, 휴애리, 혼인지 순서로 추천"), // 나열 → 시드
            post("오보롬왓츠"),                   // 단어 중간 일치는 전파 안 함
        ]
        let candidates = extractor.extract(from: posts)
        let counts = Dictionary(uniqueKeysWithValues: candidates.map { ($0.name, $0.mentionCount) })
        #expect(counts["보롬왓"] == 2)
        #expect(counts["혼인지"] == 3)
        #expect(counts["카멜리아힐"] == 1)
        #expect(counts["휴애리"] == 1)
        #expect(candidates.first?.name == "혼인지")
    }

    @Test func anchorPassSkipsVerbForms() {
        #expect(names("찍은 수국 따라 수국 올라 수국").isEmpty)
        #expect(names("안반데기 은하수") == ["안반데기"])
    }

    @Test func themeWordWithSuffixIsGeneric() {
        #expect(!names("종달리 수국길 드라이브").contains("수국길"))
    }
}
