import AppKit
import Charts
import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct SettingsView: View {
    @AppStorage(AppStorageKeys.refreshIntervalSeconds) private var refreshInterval = 60
    @AppStorage(AppStorageKeys.menuBarDisplayMode) private var displayModeRaw = MenuBarDisplayMode.concise.rawValue
    @AppStorage(AppStorageKeys.lowQuotaNotificationEnabled) private var lowQuotaNotification = true
    @AppStorage(AppStorageKeys.lowQuotaThresholdPercent) private var lowQuotaThreshold = 10
    @AppStorage(AppStorageKeys.lowQuotaRecoverPercent) private var lowQuotaRecover = 20
    @AppStorage(AppStorageKeys.prefersAutomaticUpdateInstall) private var autoUpdate = false

    @State private var historyRecords: [DailyUsageRecord] = []

    /// 外部传入的默认选中的标签页索引（0=通用, 1=用量历史）
    var defaultTabIndex: Int? = nil

    @State private var selectedTab: Int = 0

    private var displayMode: MenuBarDisplayMode {
        MenuBarDisplayMode(rawValue: displayModeRaw) ?? .concise
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            generalTab
                .tabItem { Label("通用", systemImage: "gearshape") }
                .tag(0)
            historyTab
                .tabItem { Label("用量历史", systemImage: "chart.bar") }
                .tag(1)
        }
        .frame(minWidth: 520, minHeight: 400)
        .onAppear {
            if let tab = defaultTabIndex {
                selectedTab = tab
            }
            reloadHistory()
        }
    }

    private var generalTab: some View {
        Form {
            Section("刷新") {
                Picker("自动刷新间隔", selection: $refreshInterval) {
                    Text("30 秒").tag(30)
                    Text("60 秒").tag(60)
                    Text("2 分钟").tag(120)
                    Text("5 分钟").tag(300)
                }
                .onChange(of: refreshInterval) { _ in postPrefsChanged() }
            }
            Section("菜单栏") {
                Picker("显示模式", selection: $displayModeRaw) {
                    ForEach(MenuBarDisplayMode.allCases) { mode in
                        Text(mode.title).tag(mode.rawValue)
                    }
                }
                .onChange(of: displayModeRaw) { _ in postPrefsChanged() }
            }
            Section("通知") {
                Toggle("低配额系统通知", isOn: $lowQuotaNotification)
                Stepper("提醒阈值：低于 \(lowQuotaThreshold)%", value: $lowQuotaThreshold, in: 5...40)
                Stepper("恢复阈值：≥ \(lowQuotaRecover)% 后重置提醒", value: $lowQuotaRecover, in: 10...90)
            }
            Section("更新") {
                Toggle("发现新版本自动下载并安装", isOn: $autoUpdate)
            }
            Section("启动") {
                Toggle("登录时启动", isOn: Binding(
                    get: { LaunchAtLoginService.isEnabled },
                    set: { LaunchAtLoginService.isEnabled = $0 }
                ))
            }
            Section("诊断") {
                HStack {
                    Text("上次请求耗时")
                    Spacer()
                    Text("\(APIMetrics.lastFetchDurationMs) ms").foregroundColor(.secondary)
                }
                if let at = APIMetrics.lastFetchAt {
                    HStack {
                        Text("上次成功时间")
                        Spacer()
                        Text(at.formatted(date: .abbreviated, time: .shortened)).foregroundColor(.secondary)
                    }
                }
                if let err = APIMetrics.lastErrorDescription {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }

    private var historyTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("按日聚合已用量（interval 已用次数）；数据存于 Application Support。")
                .font(.caption)
                .foregroundColor(.secondary)
            HStack {
                Button("刷新列表") { reloadHistory() }
                Button("导出 CSV…") { exportCSV() }
            }
            if historyRecords.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text("暂无历史")
                        .font(.headline)
                    Text("成功拉取配额后会自动记录当日快照。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                Chart(historyRecords.sorted(by: { $0.dateKey < $1.dateKey }).suffix(14)) { rec in
                    BarMark(
                        x: .value("日", rec.formattedDate),
                        y: .value("已用", rec.totalConsumed)
                    )
                    .foregroundStyle(Color.accentColor.gradient)
                }
                .frame(height: 200)
                List(historyRecords.prefix(30)) { rec in
                    HStack {
                        Text(rec.dateKey)
                        Spacer()
                        Text(rec.primaryModelName).foregroundColor(.secondary)
                        Text("\(rec.totalConsumed)").monospacedDigit()
                    }
                }
                .frame(minHeight: 160)
            }
            Spacer()
        }
        .padding()
    }

    private func reloadHistory() {
        historyRecords = (try? UsageHistorySQLiteStore.shared.loadDailyRecords(limit: 90)) ?? []
    }

    private func exportCSV() {
        let service = ExportService()
        try? service.exportCSV(from: UsageHistorySQLiteStore.shared)
    }

    private func postPrefsChanged() {
        NotificationCenter.default.post(name: .minimaxPreferencesDidChange, object: nil)
    }
}
