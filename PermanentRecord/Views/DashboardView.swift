//
//  DashboardView.swift
//  仪表板视图
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showStatusHelp = false
    @State private var statusHelpMessage = ""
    @State private var hideSensitiveNumbers = true

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 总资产/总收益卡片
                HStack(spacing: 12) {
                    totalAssetsCard
                    totalReturnCard
                }

                // 资产卡片网格
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 150), spacing: 15)
                ], spacing: 15) {
                    ForEach(dataManager.assets) { asset in
                        NavigationLink(destination: AssetEditView(asset: asset)) {
                            AssetCard(asset: asset)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // 状态监控
                rebalanceMonitorSection

                // 提醒设置
                reminderSection

                // 最近记录
                recentRecordsSection
            }
            .padding()
        }
        .onAppear {
            hideSensitiveNumbers = true
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    hideSensitiveNumbers.toggle()
                }) {
                    Image(systemName: hideSensitiveNumbers ? "eye.slash" : "eye")
                }
                .accessibilityLabel(hideSensitiveNumbers ? "显示金额" : "隐藏金额")
            }
        }
        .alert("状态说明", isPresented: $showStatusHelp) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(statusHelpMessage)
        }
    }

    // 总资产卡片
    private var totalAssetsCard: some View {
        Card {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.tertiary)
                        Text("总资产")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }

                    Spacer()

                    if let portfolio = dataManager.portfolio {
                        Text(displayCurrency(portfolio.formattedTotalAssets))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.green)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // 总收益卡片
    private var totalReturnCard: some View {
        Card {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 24))
                            .foregroundStyle(.tertiary)
                        Text("总收益")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }

                    Spacer()

                    if let portfolio = dataManager.portfolio {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(displayCurrency(portfolio.formattedTotalReturn))
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(portfolio.totalReturn >= 0 ? .green : .red)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)

                            Text("收益率: \(portfolio.formattedReturnRate)")
                                .font(.system(size: 16))
                                .foregroundColor(portfolio.returnRate >= 0 ? .green : .red)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // 资产卡片
    private func AssetCard(asset: Asset) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: asset.type.icon)
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: asset.type.color))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(asset.type.displayName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)

                        Text(asset.name)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Text("代码: \(asset.code)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Text(String(format: "占比: %.2f%%", dataManager.currentAllocationPercent(for: asset.type)))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("当前")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)

                        Spacer()

                        Text(displayCurrency(asset.formattedCurrentValue))
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .layoutPriority(1)
                    }

                    HStack {
                        Text("本金")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)

                        Spacer()

                        Text(displayCurrency(asset.formattedPrincipal))
                            .font(.system(size: 16))
                            .foregroundColor(.primary)
                    }

                    HStack {
                        Text("收益")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)

                        Spacer()

                        Text(displayCurrency(asset.formattedReturnValue))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(asset.returnValue >= 0 ? .green : .red)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .layoutPriority(1)

                        Text(asset.formattedReturnRate)
                            .font(.system(size: 14))
                            .foregroundColor(asset.returnRate >= 0 ? .green : .red)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 210, alignment: .topLeading)
        .overlay(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(hex: asset.type.color), lineWidth: 4)
                .frame(height: 8)
                .padding(.leading, 12)
        }
    }

    // 状态监控
    private var rebalanceMonitorSection: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("状态监控", systemImage: "waveform.path.ecg")
                        .font(.headline)
                    Spacer()
                    Text(abs(dataManager.targetTotalPercent - 100) < 0.0001 ? "配置有效" : "配置错误")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background((abs(dataManager.targetTotalPercent - 100) < 0.0001 ? Color.green : Color.red).opacity(0.15), in: Capsule())
                        .foregroundColor(abs(dataManager.targetTotalPercent - 100) < 0.0001 ? .green : .red)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("再平衡阈值")
                            .font(.subheadline)
                        Spacer()
                        Text(String(format: "%.1f%%", dataManager.rebalanceThresholdPercent))
                            .font(.subheadline.weight(.semibold))
                    }

                    Stepper(
                        "调整阈值",
                        value: $dataManager.rebalanceThresholdPercent,
                        in: 0...50,
                        step: 0.5
                    )
                    .labelsHidden()
                }
                .padding(10)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 8) {
                    Text("目标配置比例")
                        .font(.subheadline.weight(.semibold))
                    targetRow(type: .stock, value: $dataManager.targetStockPercent)
                    targetRow(type: .bond, value: $dataManager.targetBondPercent)
                    targetRow(type: .gold, value: $dataManager.targetGoldPercent)
                    targetRow(type: .cash, value: $dataManager.targetCashPercent)

                    Text(String(format: "目标合计: %.1f%%", dataManager.targetStockPercent + dataManager.targetBondPercent + dataManager.targetGoldPercent + dataManager.targetCashPercent))
                        .font(.caption)
                        .foregroundColor(dataManager.isTargetAllocationValid ? .secondary : .red)
                }
                .padding(10)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))

                if let error = dataManager.targetAllocationValidationMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                }

                ForEach(AssetType.allCases, id: \.self) { type in
                    HStack {
                        Image(systemName: type.icon)
                            .foregroundColor(Color(hex: type.color))
                            .frame(width: 18)
                        Text(type.displayName)
                            .font(.subheadline.weight(.semibold))
                        Spacer()

                        Text(String(format: "当前 %.2f%%", dataManager.currentAllocationPercent(for: type)))
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)

                        let deviation = dataManager.allocationDeviationPercent(for: type)
                        Text(String(format: "%@%.2f%%", deviation >= 0 ? "+" : "", deviation))
                            .font(.subheadline.monospacedDigit())
                            .foregroundColor(abs(deviation) > dataManager.rebalanceThresholdPercent ? .orange : .secondary)

                        Button(action: {
                            statusHelpMessage = statusExplanation(for: type, deviation: deviation)
                            showStatusHelp = true
                        }) {
                            Text(dataManager.isTargetAllocationValid ? dataManager.rebalanceStatus(for: type) : "⚠ 配置")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(dataManager.isTargetAllocationValid ? (abs(deviation) > dataManager.rebalanceThresholdPercent ? .orange : .green) : .red)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    @ViewBuilder
    private func targetRow(type: AssetType, value: Binding<Double>) -> some View {
        HStack {
            Image(systemName: type.icon)
                .foregroundColor(Color(hex: type.color))
                .frame(width: 16)
            Text(type.displayName)
                .font(.caption)
            Spacer()
            Stepper(value: value, in: 0...100, step: 0.5) {
                Text(String(format: "%.1f%%", value.wrappedValue))
                    .font(.caption.monospacedDigit())
            }
            .labelsHidden()
            Text(String(format: "%.1f%%", value.wrappedValue))
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
        }
    }

    private func statusExplanation(for type: AssetType, deviation: Double) -> String {
        let threshold = dataManager.rebalanceThresholdPercent
        let current = dataManager.currentAllocationPercent(for: type)
        let target = dataManager.targetAllocationPercent(for: type)

        if !dataManager.isTargetAllocationValid {
            return String(
                format: "当前目标配置合计为 %.1f%%，不等于100%%，请先修正目标配置后再判断是否需要再平衡。",
                dataManager.targetTotalPercent
            )
        }

        if abs(deviation) > threshold {
            return String(
                format: "%@当前占比 %.2f%%，目标占比 %.2f%%，偏差 %.2f%%，已超过阈值 %.2f%%，因此显示 ⚠️平衡。",
                type.displayName, current, target, deviation, threshold
            )
        } else {
            return String(
                format: "%@当前占比 %.2f%%，目标占比 %.2f%%，偏差 %.2f%%，未超过阈值 %.2f%%，因此显示 ✅ 正常。只有当偏差绝对值大于阈值时，才会显示 ⚠️平衡。",
                type.displayName, current, target, deviation, threshold
            )
        }
    }

    private func displayCurrency(_ value: String) -> String {
        hideSensitiveNumbers ? "¥****" : value
    }

    private var reminderSection: some View {
        NavigationLink(destination: ReminderSettingsView()) {
            Card {
                HStack(spacing: 12) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("记录提醒")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("设置每天或每周提醒你添加记录")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // 最近记录
    private var recentRecordsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)

                Text("最近记录")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                NavigationLink(destination: RecordListView()) {
                    Text("查看全部")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.blue)
                }
            }

            if dataManager.records.isEmpty {
                Text("暂无记录，点击下方\"添加记录\"开始")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.gray.opacity(0.1)))
                    .cornerRadius(8)
            }
        }
    }
}

struct AssetEditView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dataManager: DataManager

    let asset: Asset
    @State private var name: String
    @State private var code: String
    @FocusState private var isInputFocused: Bool

    init(asset: Asset) {
        self.asset = asset
        _name = State(initialValue: asset.name)
        _code = State(initialValue: asset.code)
    }

    var body: some View {
        Form {
            Section(header: Text("资产类型")) {
                Text(asset.type.displayName)
                    .foregroundColor(.secondary)
            }

            Section(header: Text("基础信息")) {
                TextField("资产名称", text: $name)
                    .textContentType(.none)
                    .autocorrectionDisabled(true)
                    .focused($isInputFocused)
                TextField("资产编号", text: $code)
                    .keyboardType(.asciiCapable)
                    .textContentType(.none)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .focused($isInputFocused)
            }
        }
        .navigationTitle("编辑资产")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    saveAsset()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") {
                    isInputFocused = false
                }
            }
        }
    }

    private func saveAsset() {
        var updated = asset
        updated.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.code = code.trimmingCharacters(in: .whitespacesAndNewlines)
        dataManager.updateAsset(updated)
        dismiss()
    }
}

// 卡片组件
struct Card<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.16), radius: 5, x: 0, y: 2)
    }
}

// 资产类型扩展
extension AssetType {
    var icon: String {
        switch self {
        case .stock: return "chart.line.uptrend.xyaxis"
        case .bond: return "doc.text.fill"
        case .gold: return "bitcoinsign.circle"
        case .cash: return "dollarsign.circle"
        }
    }
}

// Color 扩展
extension Color {
    init(hex: String) {
        let hexSanitized = hex.replacingOccurrences(of: "#", with: "")
        guard hexSanitized.count == 6, let rgb = UInt64(hexSanitized, radix: 16) else {
            self = .clear
            return
        }

        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}
