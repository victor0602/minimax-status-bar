import Charts
import SwiftUI

struct UsageHistoryPanelView: View {
    let records: [DailyUsageRecord]
    let onRefresh: () -> Void
    let onExport: () -> Void

    @State private var selectedDateKey: String?

    private var recentRecords: [DailyUsageRecord] {
        records.sorted(by: { $0.dateKey > $1.dateKey })
    }

    private var chartRecords: [DailyUsageRecord] {
        Array(recentRecords.prefix(14).reversed())
    }

    private var selectedRecord: DailyUsageRecord? {
        if let key = selectedDateKey, let found = recentRecords.first(where: { $0.dateKey == key }) {
            return found
        }
        return recentRecords.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: UISpec.contentVerticalPadding) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Label("用量历史", systemImage: "chart.bar")
                        .font(.system(size: 12, weight: .semibold))
                    Text("最近 14 天趋势 · 最近 8 条明细")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer()
                actionButton(icon: "arrow.clockwise", label: "刷新", action: onRefresh)
                actionButton(icon: "square.and.arrow.up", label: "导出", action: onExport)
            }
            .padding(.horizontal, UISpec.contentHorizontalPadding)
            .padding(.top, UISpec.contentVerticalPadding)

            if records.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                    Text("暂无历史数据")
                        .font(.system(size: 11, weight: .medium))
                    Text("成功拉取配额后会自动记录。")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .padding(.horizontal, UISpec.contentHorizontalPadding)
            } else {
                Chart(chartRecords) { rec in
                    BarMark(
                        x: .value("日", rec.formattedDate),
                        y: .value("已用", rec.totalConsumed)
                    )
                    .foregroundStyle(Color.accentColor.gradient)
                }
                .frame(height: 110)
                .padding(.horizontal, UISpec.contentHorizontalPadding)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 7))
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }

                VStack(spacing: 0) {
                    HStack {
                        Text("日期")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("模型")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("已用")
                            .frame(width: 54, alignment: .trailing)
                    }
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                    .padding(.horizontal, UISpec.contentHorizontalPadding)
                    .padding(.bottom, 4)

                    ForEach(Array(recentRecords.prefix(8).enumerated()), id: \.element.id) { idx, rec in
                        HStack(spacing: 10) {
                            Button(action: { selectedDateKey = rec.dateKey }) {
                                Text(rec.dateKey)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(selectedDateKey == rec.dateKey ? .accentColor : .secondary)
                                    .underline(selectedDateKey == rec.dateKey)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .modifier(HistoryDateButtonHoverModifier(isSelected: selectedDateKey == rec.dateKey))

                            Text(rec.primaryModelName)
                                .font(.system(size: 10))
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(rec.totalConsumed)")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .frame(width: 54, alignment: .trailing)
                        }
                        .padding(.horizontal, UISpec.contentHorizontalPadding)
                        .padding(.vertical, 6)
                        .background(
                            idx.isMultiple(of: 2)
                                ? Color.primary.opacity(0.025)
                                : Color.clear
                        )

                        if idx != min(7, recentRecords.count - 1) {
                            Divider().padding(.leading, UISpec.contentHorizontalPadding)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: UISpec.buttonCornerRadius))
                .padding(.horizontal, UISpec.contentHorizontalPadding)

                if let selected = selectedRecord {
                    dailyBreakdownChart(for: selected)
                        .padding(.horizontal, UISpec.contentHorizontalPadding)
                }
                Spacer(minLength: 0)
                    .frame(height: UISpec.contentVerticalPadding)
            }
        }
        .ifPlatformCard()
        .padding(.horizontal, UISpec.contentVerticalPadding)
        .onAppear {
            if selectedDateKey == nil {
                selectedDateKey = recentRecords.first?.dateKey
            }
        }
        .onChange(of: records.count) { _ in
            if selectedDateKey == nil || !recentRecords.contains(where: { $0.dateKey == selectedDateKey }) {
                selectedDateKey = recentRecords.first?.dateKey
            }
        }
    }

    private func actionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
        .ifPlatformButton()
    }

    private func dailyBreakdownChart(for record: DailyUsageRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(record.dateKey) 当日模型用量")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
            Chart(record.modelUsages.sorted(by: { $0.consumed > $1.consumed }).prefix(6), id: \.modelName) { usage in
                BarMark(
                    x: .value("已用", usage.consumed),
                    y: .value("模型", usage.modelName)
                )
                .foregroundStyle(Color.accentColor.opacity(0.75))
            }
            .frame(height: 120)
            .chartLegend(.hidden)
        }
        .padding(10)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: UISpec.cardCornerRadius))
    }
}

private struct HistoryDateButtonHoverModifier: ViewModifier {
    let isSelected: Bool
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        isSelected
                            ? Color.accentColor.opacity(0.14)
                            : Color.accentColor.opacity(isHovered ? 0.08 : 0.0)
                    )
            )
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

