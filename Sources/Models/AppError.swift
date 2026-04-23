import Foundation

enum AppError: Error, LocalizedError {
    case api(MiniMaxAPIError)
    case networkUnavailable
    case unknown(Error)

    static func wrap(_ error: Error) -> AppError {
        if let e = error as? AppError { return e }
        if let api = error as? MiniMaxAPIError { return .api(api) }
        return .unknown(error)
    }

    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "网络不可用"

        case .api(let apiError):
            switch apiError {
            case .missingAPIKey:
                return """
                未找到 MiniMax API Key

                自动查找路径：
                1. 环境变量 MINIMAX_API_KEY
                2. 本机 Keychain（应用内“保存并使用”）
                3. ~/.openclaw/.env
                4. ~/.openclaw/openclaw.json

                OpenClaw 用户重启 app 即可自动读取
                其他用户请在终端执行：
                export MINIMAX_API_KEY=your_key
                """

            case .serverError(401):
                return """
                API Key 验证失败（401）

                请确认使用的是 Token Plan Key
                而非普通 Open Platform API Key

                Token Plan Key 以 sk-cp- 开头
                前往：platform.minimaxi.com/user-center/payment/token-plan
                获取 Token Plan Key
                """

            case .serverError(let code):
                return "服务器错误（HTTP \(code)）"

            case .networkError(let err):
                return AppError.sanitizedMessage(err.localizedDescription)

            case .apiError(let msg):
                return msg

            case .invalidURL:
                return "请求地址无效"
            case .invalidResponse:
                return "响应格式异常"
            case .decodingError:
                return "响应解析失败"
            }

        case .unknown(let error):
            return AppError.sanitizedMessage(error.localizedDescription)
        }
    }

    private static func sanitizedMessage(_ message: String) -> String {
        message.replacingOccurrences(
            of: #"\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}"#,
            with: "[IP]",
            options: .regularExpression
        )
    }
}

