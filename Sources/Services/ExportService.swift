import Foundation
import AppKit

/// 用量历史导出错误
enum ExportError: Error, LocalizedError {
    case noData
    case writeFailed
    case cancelled
    case storageUnavailable

    var errorDescription: String? {
        switch self {
        case .noData: return "没有可用数据"
        case .writeFailed: return "写入文件失败"
        case .cancelled: return "用户取消"
        case .storageUnavailable: return "历史存储不可用"
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
    ///
    /// 使用 sheet 模式异步回调，不在主线程阻塞。
    /// - Parameters:
    ///   - store: 数据源
    ///   - fileName: 默认文件名
    ///   - completion: 导出结果回调（成功返回文件 URL，失败返回具体错误）
    func exportCSV(
        from store: UsageHistorySQLiteStore,
        fileName: String = "minimax-usage-history.csv",
        completion: ((Result<URL, Error>) -> Void)? = nil
    ) {
        // 先检查存储是否可用，避免误报"无数据"
        guard store.isAvailable else {
            completion?(.failure(ExportError.storageUnavailable))
            return
        }

        do {
            let records = try store.loadDailyRecords(limit: 10_000)
            let csv = generateCSV(from: records)

            let panel = NSSavePanel()
            panel.allowedContentTypes = [.commaSeparatedText]
            panel.nameFieldStringValue = fileName
            panel.canCreateDirectories = true

            if let window = NSApp.keyWindow ?? NSApp.mainWindow {
                panel.beginSheetModal(for: window) { response in
                    if response == .OK, let url = panel.url {
                        do {
                            try csv.write(to: url, atomically: true, encoding: .utf8)
                            completion?(.success(url))
                        } catch {
                            completion?(.failure(error))
                        }
                    } else {
                        completion?(.failure(ExportError.cancelled))
                    }
                }
            } else {
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                do {
                    try csv.write(to: url, atomically: true, encoding: .utf8)
                    completion?(.success(url))
                } catch {
                    completion?(.failure(ExportError.writeFailed))
                }
            }
        } catch let error as UsageHistoryError {
            // 区分"存储不可用"和"无数据"两种错误反馈
            completion?(.failure(error))
        } catch {
            completion?(.failure(error))
        }
    }

    /// 生成 CSV 并写入 URL（非交互式，用于单测或静默导出）
    func writeCSV(from records: [DailyUsageRecord], to url: URL) throws {
        let csv = generateCSV(from: records)
        try csv.write(to: url, atomically: true, encoding: .utf8)
    }
}
