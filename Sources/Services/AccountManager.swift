import Foundation

/// 多账户配置（密钥存于 UserDefaults，仅适合个人开发机；共享电脑请关闭「多账户」）。
struct StoredAccount: Codable, Identifiable, Equatable {
    var id: UUID
    var displayName: String
    var apiKey: String
}

@MainActor
final class AccountManager: ObservableObject {
    static let shared = AccountManager()

    @Published var multiAccountEnabled: Bool {
        didSet { UserDefaults.standard.set(multiAccountEnabled, forKey: AppStorageKeys.multiAccountEnabled) }
    }

    @Published var accounts: [StoredAccount] = [] {
        didSet { saveAccounts() }
    }

    @Published var activeAccountId: UUID? {
        didSet {
            if let id = activeAccountId {
                UserDefaults.standard.set(id.uuidString, forKey: AppStorageKeys.activeAccountId)
            } else {
                UserDefaults.standard.removeObject(forKey: AppStorageKeys.activeAccountId)
            }
        }
    }

    private init() {
        multiAccountEnabled = UserDefaults.standard.bool(forKey: AppStorageKeys.multiAccountEnabled)
        loadAccounts()
        if let s = UserDefaults.standard.string(forKey: AppStorageKeys.activeAccountId),
           let u = UUID(uuidString: s) {
            activeAccountId = u
        }
    }

    private func loadAccounts() {
        guard let data = UserDefaults.standard.data(forKey: AppStorageKeys.storedAccountsJSON),
              let decoded = try? JSONDecoder().decode([StoredAccount].self, from: data) else {
            accounts = []
            return
        }
        accounts = decoded
    }

    private func saveAccounts() {
        guard let data = try? JSONEncoder().encode(accounts) else { return }
        UserDefaults.standard.set(data, forKey: AppStorageKeys.storedAccountsJSON)
    }

    func addAccount(displayName: String, apiKey: String) {
        let acc = StoredAccount(id: UUID(), displayName: displayName, apiKey: apiKey)
        accounts.append(acc)
        if activeAccountId == nil { activeAccountId = acc.id }
    }

    func removeAccount(id: UUID) {
        accounts.removeAll { $0.id == id }
        if activeAccountId == id { activeAccountId = accounts.first?.id }
    }

    /// 多账户开启时返回当前配置 Key；否则 `nil`（由调用方回退 `APIKeyResolver`）。
    func apiKeyForActiveAccount() -> String? {
        guard multiAccountEnabled, let id = activeAccountId,
              let acc = accounts.first(where: { $0.id == id }) else { return nil }
        let k = acc.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return k.isEmpty ? nil : k
    }
}
