import XCTest
@testable import MiniMax_Status_Bar

final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    static var errorHandler: ((URLRequest) throws -> Error)?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let client else { return }
        do {
            if let errorHandler = Self.errorHandler {
                let err = try errorHandler(request)
                client.urlProtocol(self, didFailWithError: err)
                return
            }
            guard let handler = Self.requestHandler else {
                XCTFail("MockURLProtocol.requestHandler not set")
                return
            }
            let (response, data) = try handler(request)
            client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client.urlProtocol(self, didLoad: data)
            client.urlProtocolDidFinishLoading(self)
        } catch {
            client.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

final class MiniMaxAPIServiceTests: XCTestCase {
    private func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        MockURLProtocol.errorHandler = nil
        super.tearDown()
    }

    func testFetchQuota_NetworkError_ThrowsNetworkError() async {
        let session = makeSession()
        MockURLProtocol.errorHandler = { _ in URLError(.timedOut) }
        let sut = MiniMaxAPIService(apiKey: "sk-cp-valid-key-placeholder", session: session)

        do {
            _ = try await sut.fetchQuota()
            XCTFail("expected throw")
        } catch let e as MiniMaxAPIError {
            guard case .networkError = e else {
                XCTFail("expected networkError, got \(e)")
                return
            }
        } catch {
            XCTFail("wrong error type \(error)")
        }
    }

    func testFetchQuota_HTTPNon200_ThrowsServerError() async {
        let session = makeSession()
        MockURLProtocol.requestHandler = { req in
            let url = req.url!
            let resp = HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (resp, Data())
        }
        let sut = MiniMaxAPIService(apiKey: "sk-cp-valid-key-placeholder", session: session)

        do {
            _ = try await sut.fetchQuota()
            XCTFail("expected throw")
        } catch let e as MiniMaxAPIError {
            guard case .serverError(500) = e else {
                XCTFail("expected serverError(500), got \(e)")
                return
            }
        } catch {
            XCTFail("wrong error type \(error)")
        }
    }

    func testFetchQuota_DecodeFailure_ThrowsDecodingError() async {
        let session = makeSession()
        MockURLProtocol.requestHandler = { req in
            let url = req.url!
            let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data("not-json".utf8))
        }
        let sut = MiniMaxAPIService(apiKey: "sk-cp-valid-key-placeholder", session: session)

        do {
            _ = try await sut.fetchQuota()
            XCTFail("expected throw")
        } catch let e as MiniMaxAPIError {
            guard case .decodingError = e else {
                XCTFail("expected decodingError, got \(e)")
                return
            }
        } catch {
            XCTFail("wrong error type \(error)")
        }
    }

    func testFetchQuota_BaseRespStatusNotZero_ThrowsAPIError() async {
        let session = makeSession()
        let payload = """
        {
          "base_resp": { "status_code": 1, "status_msg": "bad key" },
          "model_remains": []
        }
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { req in
            let url = req.url!
            let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, payload)
        }
        let sut = MiniMaxAPIService(apiKey: "sk-cp-valid-key-placeholder", session: session)

        do {
            _ = try await sut.fetchQuota()
            XCTFail("expected throw")
        } catch let e as MiniMaxAPIError {
            guard case .apiError(let msg) = e else {
                XCTFail("expected apiError, got \(e)")
                return
            }
            XCTAssertEqual(msg, "bad key")
        } catch {
            XCTFail("wrong error type \(error)")
        }
    }

    func testFetchQuota_DebugBuildInjectsRequestID() async throws {
        let session = makeSession()
        let payload = """
        {
          "base_resp": { "status_code": 0, "status_msg": "" },
          "model_remains": []
        }
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { req in
            #if DEBUG
            XCTAssertNotNil(req.value(forHTTPHeaderField: "X-Request-ID"))
            #endif
            let url = req.url!
            let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, payload)
        }
        let sut = MiniMaxAPIService(apiKey: "sk-cp-valid-key-placeholder", session: session)

        _ = try await sut.fetchQuota()
    }
}
