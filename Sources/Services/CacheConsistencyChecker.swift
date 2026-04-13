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

    /// 对拍本次拉取与上次缓存，发现明显异常（模型大量消失、totalCount 大幅变化等）。
    static func validationIssues(for models: [ModelQuota], against cached: [ModelQuota]) -> [String] {
        var issues = validationIssues(for: models)

        guard !cached.isEmpty else { return issues }

        let newNames = Set(models.map(\.modelName))
        let cachedNames = Set(cached.map(\.modelName))

        let missing = cachedNames.subtracting(newNames)
        let added = newNames.subtracting(cachedNames)

        if models.count < max(1, cached.count / 2) {
            issues.append("model list shrank suspiciously: cached=\(cached.count), new=\(models.count)")
        }

        if missing.count >= 3 {
            issues.append("models missing vs cache: \(missing.sorted().joined(separator: ", "))")
        }

        if added.count >= 3 {
            issues.append("models added vs cache: \(added.sorted().joined(separator: ", "))")
        }

        let cachedByName = Dictionary(uniqueKeysWithValues: cached.map { ($0.modelName, $0) })
        for m in models {
            guard let old = cachedByName[m.modelName] else { continue }
            guard old.totalCount > 0, m.totalCount > 0 else { continue }
            if old.totalCount != m.totalCount {
                issues.append("\(m.modelName): totalCount changed \(old.totalCount) → \(m.totalCount)")
            }
        }

        return issues
    }

    static func modelsLookConsistent(_ models: [ModelQuota]) -> Bool {
        validationIssues(for: models).isEmpty
    }
}
