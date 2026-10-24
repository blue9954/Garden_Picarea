import Foundation

/// GardenCore의 모든 실패 유형. Provider 단위로 격리되어 부분 결과를 허용한다.
public enum GardenError: Error, Equatable, Sendable, LocalizedError {
    case missingCredentials(provider: String)
    case unauthorized(provider: String)
    case rateLimited(provider: String, retryAfter: TimeInterval?)
    case http(provider: String, status: Int)
    case decoding(provider: String, message: String)
    case transport(provider: String, message: String)
    case invalidRequest(provider: String, message: String)

    public var provider: String {
        switch self {
        case .missingCredentials(let p), .unauthorized(let p), .rateLimited(let p, _),
             .http(let p, _), .decoding(let p, _), .transport(let p, _), .invalidRequest(let p, _):
            p
        }
    }

    public var errorDescription: String? {
        switch self {
        case .missingCredentials(let p): "\(p): API 키가 설정되지 않았어요."
        case .unauthorized(let p): "\(p): API 키 인증에 실패했어요. 키를 확인해 주세요."
        case .rateLimited(let p, _): "\(p): 호출 한도를 초과했어요. 잠시 후 다시 시도해 주세요."
        case .http(let p, let status): "\(p): 서버 오류 (HTTP \(status))."
        case .decoding(let p, _): "\(p): 응답 형식이 바뀌었어요."
        case .transport(let p, _): "\(p): 네트워크에 연결할 수 없어요."
        case .invalidRequest(let p, let m): "\(p): 잘못된 요청 (\(m))."
        }
    }

    /// 상태 코드를 GardenError로 매핑. 2xx는 nil.
    static func from(status: Int, provider: String, headers: [String: String]) -> GardenError? {
        switch status {
        case 200..<300: return nil
        case 401, 403: return .unauthorized(provider: provider)
        case 429:
            let retry = headers.first { $0.key.lowercased() == "retry-after" }.flatMap { TimeInterval($0.value) }
            return .rateLimited(provider: provider, retryAfter: retry)
        default: return .http(provider: provider, status: status)
        }
    }
}
