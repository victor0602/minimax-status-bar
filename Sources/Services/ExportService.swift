import Foundation
import AppKit

/// 用量历史导出错误
enum ExportError: Error, LocalizedError {
    case noData
    case writeFailed
    case cancelled

    var errorDescription: String? {
        switch self {
        case .noData: return "没有可用数据"
        case .writeFailed: return "写入文件失败"
        case .cancelled: return "用户取消"
        }
    }
}

/// 用量历史导出服务
/// 职责：从存储层获取数据，生成 CSV 格式，写入用户指定位置
final class ExportService {
    /// 默认文件名
    static let defaultFileName = "minimax-usage-history.csv"

    /// 默认 CSV 表头
    static let csvHeader = "date_key,primary_model,total_consumed"

    /// 从记录列表生成 CSV 字符串
    func generateCSV(from records: [DailyUsageRecord]) -> String {
        var lines = [Self.csvHeader]
        for r in records.sorted(by: { $0.dateKey < $1.dateKey }) {
            let escapedModel = r.primaryModelName.replacingOccurrences(of: ",", with: ";")
            lines.append("\(r.dateKey),\(escapedModel),\(r.totalConsumed)")
        }
        return lines.joined(separator: "\n")
    }

    /// 导出 CSV（交互式：弹出 NSSavePanel）
    /// - Parameters:
    ///   - store: 数据源
    ///   - fileName: 默认文件名
    func exportCSV(from store: UsageHistorySQLiteStore, fileName: String = "minimax-usage-history.csv") throws {
        let records = try store.loadDailyRecords(limit: 10_000)
        guard !records.isEmpty else {
            throw ExportError.noData
        }

        let csv = generateCSV(from: records)

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = fileName
        panel.canCreateDirectories = true

        // 尝试获取窗口用于 sheet 模式
        if let window = NSApp.keyWindow ?? NSApp.mainWindow {
            var saveError: Error?
            let semaphore = DispatchSemaphore(value: 0)

            panel.beginSheetModal(for: window) { response in
                if response == .OK, let url = panel.url {
                    do {
                        try csv.write(to: url, atomically: true, encoding: .utf8)
                    } catch {
                        saveError = error
                    }
                } else {
                    saveError = ExportError.cancelled
                }
                semaphore.signal()
            }

            semaphore.wait()

            if let error = saveError {
                throw error
            }
        } else {
            // 无窗口时写入临时目录
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            do {
                try csv.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                throw ExportError.writeFailed
            }
        }
    }

    /// 生成 CSV 并写入 URL（非交互式，用于单测或静默导出）
    func writeCSV(from records: [DailyUsageRecord], to url: URL) throws {
        let csv = generateCSV(from: records)
        try csv.write(to: url, atomically: true, encoding: .utf8)
    }
}