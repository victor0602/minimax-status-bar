import Foundation

/// 校验单次 API 结果与 `ModelQuota` 不变量（剩余 ∈ [0, total] 等），不替代服务端权威数据。
enum CacheConsistencyChecker {
    static func validationIssues(for models: [ModelQuota]) -> [String] {
        var issues: [String] = []
        for m in models {
            if m.totalCount < 0 {
                issues.append("\(m.modelName): negative totalCount")
            }
            if m.remainingCount < 0 {
                issues.append("\(m.modelName): negative remainingCount")
            }
            if m.totalCount > 0, m.remainingCount > m.totalCount {
                issues.append("\(m.modelName): remainingCount exceeds totalCount")
            }
        }
        return issues
    }

    static func modelsLookConsistent(_ models: [ModelQuota]) -> Bool {
        validationIssues(for: models).isEmpty
    }
}
