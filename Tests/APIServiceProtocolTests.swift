import XCTest
@testable import MiniMax_Status_Bar

final class MockQuotaAPIService: APIServiceProtocol {
    var outcome: Result<[ModelQuota], Error> = .success([])

    func fetchQuota() async throws -> [ModelQuota] {
        switch outcome {
        case .success(let models):
            return models
        case .failure(let error):
            throw error
        }
    }
}

final class APIServiceProtocolTests: XCTestCase {
    func testMockReturnsDecodedModels() async throws {
        // API usage=60, total=100 → remaining=40
        let raw = ModelQuotaRaw(
            modelName: "MiniMax-M2.7",
            currentIntervalTotalCount: 100,
            currentIntervalUsageCount: 60,
            currentWeeklyTotalCount: 1000,
            currentWeeklyUsageCount: 500,
            remainsTime: 3_600_000,
            weeklyStartTime: 0,
            weeklyEndTime: 86_400_000
        )
        let model = ModelQuota.from(raw: raw)
        let mock = MockQuotaAPIService()
        mock.outcome = .success([model])
        let got = try await mock.fetchQuota()
        XCTAssertEqual(got.count, 1)
        XCTAssertEqual(got[0].remainingCount, 40)
    }

    func testMockPropagatesError() async {
        let mock = MockQuotaAPIService()
        mock.outcome = .failure(MiniMaxAPIError.missingAPIKey)
        do {
            _ = try await mock.fetchQuota()
            XCTFail("expected throw")
        } catch let error as MiniMaxAPIError {
            if case .missingAPIKey = error { return }
            XCTFail("wrong error \(error)")
        } catch {
            XCTFail("wrong type \(error)")
        }
    }
}
