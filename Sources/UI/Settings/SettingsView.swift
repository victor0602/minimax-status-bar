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
    @State private var selectedTab: Int = 0
    @State private var historyRangeDays: Int = 14
    @Namespace private var rangePickerNamespace

    var defaultTabIndex: Int? = nil
    var isEmbedded: Bool = false
    var selectedTabOverride: Binding<Int>? = nil

    private var selectedTabBinding: Binding<Int> {
        selectedTabOverride ?? $selectedTab
    }

    private var displayMode: MenuBarDisplayMode {
        MenuBarDisplayMode(rawValue: displayModeRaw) ?? .concise
    }

    private var analytics: HistoryAnalytics {
        HistoryAnalytics(allRecords: historyRecords, rangeDays: historyRangeDays)
    }

    private var filteredHistoryRecords: [DailyUsageRecord] {
        analytics.rangeRecords
    }

    private var totalConsumedInRange: Int { analytics.totalConsumed }
    private var averageConsumedInRange: Int { analytics.averageConsumed }
    private var peakRecordInRange: DailyUsageRecord? { analytics.peakRecord }

    var body: some View {
        TabView(selection: selectedTabBinding) {
            generalTab
                .tabItem { Label("通用", systemImage: "gearshape") }
                .tag(0)
            historyTab
                .tabItem { Label("用量历史", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(1)
        }
        .frame(minWidth: isEmbedded ? nil : 680, minHeight: isEmbedded ? nil : 520)
        .font(.system(size: isEmbedded ? 12 : 13))
        .onAppear {
            if let tab = defaultTabIndex {
                selectedTabBinding.wrappedValue = tab
            }
            reloadHistory()
        }
    }

    private var generalTab: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 12) {
                settingsCard(title: "刷新与菜单栏", icon: "arrow.clockwise.circle") {
                    VStack(spacing: 10) {
                        rowLabelValue("自动刷新间隔") {
                            Picker("自动刷新间隔", selection: $refreshInterval) {
                                Text("30秒").tag(30)
                                Text("60秒").tag(60)
                                Text("2分钟").tag(120)
                                Text("5分钟").tag(300)
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .onChange(of: refreshInterval) { _ in postPrefsChanged() }
                        }

                        rowLabelValue("菜单栏显示") {
                            Picker("菜单栏显示", selection: $displayModeRaw) {
                                ForEach(MenuBarDisplayMode.allCases) { mode in
                                    Text(mode.title).tag(mode.rawValue)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .onChange(of: displayModeRaw) { _ in postPrefsChanged() }
                        }

                        Text("当前模式：\(displayMode.title)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                settingsCard(title: "通知与启动", icon: "bell.badge") {
                    VStack(spacing: 10) {
                        toggleRow("低配额系统通知", isOn: $lowQuotaNotification)
                        stepperRow("提醒阈值", value: $lowQuotaThreshold, range: 5...40)
                        stepperRow("恢复阈值", value: $lowQuotaRecover, range: 10...90)
                        toggleRow("自动下载并安装更新", isOn: $autoUpdate)
                        toggleRow("登录时启动", isOn: Binding(
                            get: { LaunchAtLoginService.isEnabled },
                            set: { LaunchAtLoginService.isEnabled = $0 }
                        ))
                    }
                }

                settingsCard(title: "诊断", icon: "wrench.and.screwdriver") {
                    VStack(spacing: 10) {
                        rowLabelValue("API 超时") {
                            Picker("API 超时", selection: Binding(
                                get: { Int(APIConfigService.shared.timeoutInterval) },
                                set: { APIConfigService.shared.timeoutInterval = TimeInterval($0) }
                            )) {
                                ForEach(APIConfigService.timeoutOptions, id: \.self) { option in
                                    Text("\(Int(option))秒").tag(Int(option))
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        }

                        toggleRow("启用请求 ID", isOn: Binding(
                            get: { APIConfigService.shared.enableRequestID },
                            set: { APIConfigService.shared.enableRequestID = $0 }
                        ))

                        Divider()

                        metricRow("上次请求耗时", "\(APIMetrics.lastFetchDurationMs) ms")
                        if let at = APIMetrics.lastFetchAt {
                            metricRow("上次成功时间", at.formatted(date: .abbreviated, time: .shortened))
                        }
                        if let err = APIMetrics.lastErrorDescription {
                            Text(err)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }

                settingsCard(title: "关于", icon: "info.circle") {
                    VStack(spacing: 8) {
                        Text("Quota visibility for MiniMax power users.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("为 MiniMax 重度使用者提供实时配额感知。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        aboutLink(icon: "doc.text", title: "Token Plan Console / 控制台", url: "https://platform.minimaxi.com/user-center/payment/token-plan")
                        aboutLink(icon: "curlybraces", title: "GitHub Repository / 源码仓库", url: "https://github.com/victor0602/minimax-status-bar")
                        aboutLink(icon: "arrow.down.circle", title: "Check Releases / 检查更新", url: "https://github.com/victor0602/minimax-status-bar/releases/latest")
                        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
                        metricRow("Version / 版本", "v\(v)")
                        metricRow("License / 许可证", "MIT License")
                    }
                }
            }
            .padding(isEmbedded ? 10 : 12)
        }
    }

    private var historyTab: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 12) {
                settingsCard(title: "用量趋势", icon: "chart.line.uptrend.xyaxis") {
                    ViewThatFits(in: .horizontal) {
                        HStack {
                            Text("按日已用统计")
                                .font(.headline)
                            Spacer()
                            rangePicker
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("按日已用统计")
                                .font(.headline)
                            rangePicker
                        }
                    }

                    Text("最近 \(historyRangeDays) 天 · 共 \(filteredHistoryRecords.count) 条")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) {
                            metricChip("总已用", "\(totalConsumedInRange)")
                            metricChip("日均", "\(averageConsumedInRange)")
                            metricChip("峰值", "\(peakRecordInRange?.totalConsumed ?? 0)")
                        }
                        VStack(spacing: 8) {
                            metricChip("总已用", "\(totalConsumedInRange)")
                            metricChip("日均", "\(averageConsumedInRange)")
                            metricChip("峰值", "\(peakRecordInRange?.totalConsumed ?? 0)")
                        }
                    }

                    if filteredHistoryRecords.isEmpty {
                        emptyHistoryView
                    } else {
                        Chart(filteredHistoryRecords) { rec in
                            LineMark(
                                x: .value("日期", rec.formattedDate),
                                y: .value("已用", rec.totalConsumed)
                            )
                            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Color.accentColor)

                            PointMark(
                                x: .value("日期", rec.formattedDate),
                                y: .value("已用点位", rec.totalConsumed)
                            )
                            .symbolSize(24)
                            .foregroundStyle(Color.accentColor)
                        }
                        .frame(height: isEmbedded ? 170 : 220)
                        .chartYAxis { AxisMarks(position: .leading) }
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 4))
                        }
                    }
                }

                settingsCard(title: "明细数据", icon: "list.bullet.rectangle") {
                    HStack {
                        Button("刷新") { reloadHistory() }
                        Button("导出 CSV…") { exportCSV() }
                        Spacer()
                        Text("按日期倒序")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if historyRecords.isEmpty {
                        emptyHistoryView
                    } else {
                        if isEmbedded {
                            LazyVStack(spacing: 6) {
                                ForEach(historyRecords.prefix(40)) { rec in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(rec.dateKey).monospacedDigit()
                                            Text(rec.primaryModelName)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Text("\(rec.totalConsumed)")
                                            .monospacedDigit()
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                    .padding(.vertical, 4)
                                    Divider()
                                }
                            }
                        } else {
                            List(historyRecords.prefix(60)) { rec in
                                HStack {
                                    Text(rec.dateKey).monospacedDigit()
                                    Spacer()
                                    Text(rec.primaryModelName).foregroundColor(.secondary)
                                    Text("\(rec.totalConsumed)").monospacedDigit()
                                }
                            }
                            .frame(minHeight: 260)
                        }
                    }
                }
            }
            .padding(isEmbedded ? 10 : 12)
        }
    }

    private var rangePicker: some View {
        HStack(spacing: 10) {
            Text("范围")
                .font(.system(size: 12))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .offset(y: -1)
            HStack(spacing: 0) {
                rangePickerItem(title: "7天", value: 7)
                rangePickerItem(title: "14天", value: 14)
                rangePickerItem(title: "30天", value: 30)
            }
            .padding(2)
            .background(Color.primary.opacity(0.08), in: Capsule())
            .frame(width: isEmbedded ? nil : 220)
        }
    }

    private func rangePickerItem(title: String, value: Int) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
                historyRangeDays = value
            }
        }) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(historyRangeDays == value ? .white : .primary)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 30)
                .background(
                    ZStack {
                        if historyRangeDays == value {
                            Capsule()
                                .fill(Color.accentColor)
                                .matchedGeometryEffect(id: "range-slider", in: rangePickerNamespace)
                        }
                    }
                )
        }
        .buttonStyle(.borderless)
        .contentShape(Rectangle())
    }

    private func settingsCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 14, alignment: .center)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .baselineOffset(0.3)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.08), lineWidth: 0.8))
        .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1)
    }

    private func metricChip(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.8)
        )
    }

    private func rowLabelValue<Content: View>(_ title: String, @ViewBuilder value: () -> Content) -> some View {
        HStack(alignment: .center) {
            Text(title)
                .font(.system(size: 12))
                .lineLimit(1)
            Spacer(minLength: 8)
            value()
        }
        .contentShape(Rectangle())
    }

    private func metricRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .font(.system(size: 12))
    }

    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .contentShape(Rectangle())
        .frame(minHeight: 28)
    }

    private func stepperRow(_ title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            Text(title)
            Spacer()
            HStack(spacing: 8) {
                Text("\(value.wrappedValue)%")
                    .foregroundColor(.secondary)
                    .monospacedDigit()
                    .frame(minWidth: 38, alignment: .trailing)
                Stepper("", value: value, in: range)
                    .labelsHidden()
            }
        }
        .contentShape(Rectangle())
        .frame(minHeight: 28)
    }

    private var emptyHistoryView: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 28))
                .foregroundColor(.secondary)
            Text("暂无历史数据")
                .font(.headline)
            Text("成功拉取配额后会自动记录当日快照。")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
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

    private func aboutLink(icon: String, title: String, url: String) -> some View {
        Button(action: {
            if let u = URL(string: url) { NSWorkspace.shared.open(u) }
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon).frame(width: 16)
                Text(title).lineLimit(1)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .frame(minHeight: 26)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
    }
}
