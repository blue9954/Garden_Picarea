import Foundation

/// 검색 API 응답 텍스트 정규화: `<b>` 강조 태그, HTML 엔티티, 연속 공백 제거.
public enum TextNormalizer {
    private static let namedEntities: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " ",
        "middot": "·", "hellip": "…", "lsquo": "‘", "rsquo": "’", "ldquo": "“", "rdquo": "”",
    ]

    public static func clean(_ raw: String) -> String {
        var text = raw.replacingOccurrences(of: "<[^>]{0,200}>", with: "", options: .regularExpression)
        text = decodeEntities(text)
        // 엔티티 디코딩 후 생긴 태그(예: &lt;b&gt;)도 제거
        text = text.replacingOccurrences(of: "<[^>]{0,200}>", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func decodeEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }
        var result = ""
        result.reserveCapacity(text.count)
        var index = text.startIndex
        while index < text.endIndex {
            let char = text[index]
            guard char == "&",
                  let semicolon = text[index...].prefix(12).firstIndex(of: ";") else {
                result.append(char)
                index = text.index(after: index)
                continue
            }
            let entity = String(text[text.index(after: index)..<semicolon])
            if let decoded = decode(entity: entity) {
                result.append(decoded)
                index = text.index(after: semicolon)
            } else {
                result.append(char)
                index = text.index(after: index)
            }
        }
        return result
    }

    private static func decode(entity: String) -> String? {
        if let named = namedEntities[entity.lowercased()] { return named }
        guard entity.hasPrefix("#") else { return nil }
        let body = entity.dropFirst()
        let scalarValue: UInt32? = if body.lowercased().hasPrefix("x") {
            UInt32(body.dropFirst(), radix: 16)
        } else {
            UInt32(body, radix: 10)
        }
        return scalarValue.flatMap(Unicode.Scalar.init).map { String(Character($0)) }
    }

    /// 비교용 키: 공백·구두점 제거, 소문자.
    public static func key(_ text: String) -> String {
        String(text.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
    }
}
