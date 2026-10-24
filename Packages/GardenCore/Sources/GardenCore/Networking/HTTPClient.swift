import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct HTTPRequest: Sendable, Hashable {
    public var url: URL
    public var headers: [String: String]
    public var timeout: TimeInterval

    public init(url: URL, headers: [String: String] = [:], timeout: TimeInterval = 10) {
        self.url = url
        self.headers = headers
        self.timeout = timeout
    }
}

public struct HTTPResponse: Sendable {
    public var status: Int
    public var headers: [String: String]
    public var body: Data

    public init(status: Int, headers: [String: String] = [:], body: Data) {
        self.status = status
        self.headers = headers
        self.body = body
    }
}

/// 네트워크 추상화. 테스트에서는 MockHTTPClient로 교체한다.
public protocol HTTPClient: Sendable {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse
}

public struct URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        var urlRequest = URLRequest(url: request.url, timeoutInterval: request.timeout)
        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        // Linux FoundationNetworking 호환을 위해 continuation 기반 dataTask 사용.
        return try await withCheckedThrowingContinuation { continuation in
            let task = session.dataTask(with: urlRequest) { data, response, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let http = response as? HTTPURLResponse else {
                    continuation.resume(throwing: URLError(.badServerResponse))
                    return
                }
                var headers: [String: String] = [:]
                for (key, value) in http.allHeaderFields {
                    headers[String(describing: key)] = String(describing: value)
                }
                continuation.resume(returning: HTTPResponse(status: http.statusCode, headers: headers, body: data ?? Data()))
            }
            task.resume()
        }
    }
}

extension HTTPClient {
    /// 요청 → 상태 검사 → JSON 디코딩까지 공통 처리. 모든 실패를 GardenError로 변환한다.
    func fetchJSON<T: Decodable>(_ type: T.Type, request: HTTPRequest, provider: String) async throws -> T {
        let response: HTTPResponse
        do {
            response = try await send(request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as GardenError {
            throw error
        } catch {
            if let urlError = error as? URLError, urlError.code == .cancelled { throw CancellationError() }
            throw GardenError.transport(provider: provider, message: String(describing: error))
        }
        if let error = GardenError.from(status: response.status, provider: provider, headers: response.headers) {
            throw error
        }
        do {
            return try JSONDecoder().decode(T.self, from: response.body)
        } catch {
            throw GardenError.decoding(provider: provider, message: String(describing: error))
        }
    }
}
