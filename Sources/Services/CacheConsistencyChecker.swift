import Foundation

/// 校验单次 API 结果与 `ModelQuota` 不变量（剩余 ∈ [0, total] 等），不替代服务端权威数据。
enum CacheConsistencyChecker {
    // MARK: - 校验和

    /// 生成 ModelQuota 列表的校验和（用于缓存一致性验证）
    /// - Description: 基于模型名称和配额值生成简单校验和，便于检测缓存是否被篡改或损坏
    /// - Returns: 64位校验和的十六进制字符串
    static func checksum(for models: [ModelQuota]) -> String {
        guard !models.isEmpty else { return "empty" }

        let sorted = models.sorted { $0.modelName < $1.modelName }
        var hasher = UInt64(0)

        for model in sorted {
            let key = "\(model.modelName):\(model.totalCount):\(model.remainingCount)"
            for char in key.utf8 {
                hasher = hasher &* 31 &+ UInt64(char)
            }
        }

        return String(hasher, radix: 16, uppercase: true)
    }

    /// 验证校验和是否匹配
    /// - Parameters:
    ///   - models: 当前模型列表
    ///   - expectedChecksum: 预期的校验和
    /// - Returns: 是否匹配
    static func validateChecksum(_ models: [ModelQuota], against expectedChecksum: String) -> Bool {
        checksum(for: models) == expectedChecksum
    }

    // MARK: - 不变量校验

    /// 校验单个模型的配额不变量
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

    /// 判断模型数据是否看起来一致（无明显异常）
    static func modelsLookConsistent(_ models: [ModelQuota]) -> Bool {
        validationIssues(for: models).isEmpty
    }

    /// 判断两次数据是否实质性一致（忽略时间相关的微小变化）
    static func modelsAreSubstantiallySame(_ current: [ModelQuota], _ previous: [ModelQuota]) -> Bool {
        guard current.count == previous.count else { return false }
        guard !current.isEmpty else { return true }

        let currentByName = Dictionary(uniqueKeysWithValues: current.map { ($0.modelName, $0) })
        let previousByName = Dictionary(uniqueKeysWithValues: previous.map { ($0.modelName, $0) })

        for (name, currentModel) in currentByName {
            guard let previousModel = previousByName[name] else { return false }
            // 允许 5% 的余量波动（考虑 API 延迟）
            let diff = abs(currentModel.remainingCount - previousModel.remainingCount)
            let threshold = max(currentModel.totalCount / 20, 1)
            if currentModel.totalCount != previousModel.totalCount || diff > threshold {
                return false
            }
        }

        return true
    }
}
