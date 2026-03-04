//
//  PolicyView.swift
//  策略执行页面
//

import SwiftUI

struct PolicyView: View {
    @EnvironmentObject private var dataManager: DataManager

    @State private var actionDate = Date()
    @State private var equalBuyFund = ""
    @State private var smartInjectionFund = ""
    @State private var smartAutoFund = ""
    @State private var smartInjectionDirection: FundDirection = .deposit
    @State private var smartAutoDirection: FundDirection = .deposit

    @State private var resultMessage = ""
    @State private var showResult = false
    @State private var previewMessage = ""
    @State private var showPreviewConfirm = false
    @State private var pendingPreview: PolicyTradePreview?
    @State private var pendingAction: PolicyAction?

    @FocusState private var focusedInput: InputField?

    private enum InputField: Hashable {
        case equalBuy
        case smartInjection
        case smartAuto
    }

    private enum FundDirection: String, CaseIterable, Identifiable {
        case deposit = "存入"
        case withdraw = "取出"

        var id: String { rawValue }
    }

    var body: some View {
        Form {
            if let error = dataManager.targetAllocationValidationMessage {
                Section {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            Section(header: Text("执行日期")) {
                DatePicker("日期", selection: $actionDate, displayedComponents: [.date])
                    .datePickerStyle(.compact)
            }

            Section(header: Text("1. 按比例买入")) {
                amountField("新增资金", text: $equalBuyFund, field: .equalBuy)
                Button("执行按比例买入") {
                    runPolicy(.equalBuy, fund: parseAmount(equalBuyFund))
                }
                .disabled(parseAmount(equalBuyFund) <= 0 || !dataManager.isTargetAllocationValid)
            }

            Section(header: Text("2. 智能填坑/削峰")) {
                Picker("方向", selection: $smartInjectionDirection) {
                    ForEach(FundDirection.allCases) { direction in
                        Text(direction.rawValue).tag(direction)
                    }
                }
                .pickerStyle(.segmented)

                amountField("资金金额", text: $smartInjectionFund, field: .smartInjection)
                Button("执行智能填坑/削峰") {
                    runPolicy(
                        .smartInjection,
                        fund: signedFund(from: smartInjectionFund, direction: smartInjectionDirection)
                    )
                }
                .disabled(parseAmount(smartInjectionFund) == 0 || !dataManager.isTargetAllocationValid)
            }

            Section(header: Text("3. 强制再平衡")) {
                Text("该策略不需要输入资金，将按目标比例重分配市值与本金。")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button("执行强制再平衡") {
                    runPolicy(.fullRebalance, fund: 0)
                }
                .disabled(!dataManager.isTargetAllocationValid)
            }

            Section(header: Text("4. 智能买卖决策")) {
                Picker("方向", selection: $smartAutoDirection) {
                    ForEach(FundDirection.allCases) { direction in
                        Text(direction.rawValue).tag(direction)
                    }
                }
                .pickerStyle(.segmented)

                amountField("资金金额", text: $smartAutoFund, field: .smartAuto)
                Button("执行智能买卖决策") {
                    runPolicy(
                        .smartAutoTrade,
                        fund: signedFund(from: smartAutoFund, direction: smartAutoDirection)
                    )
                }
                .disabled(parseAmount(smartAutoFund) == 0 || !dataManager.isTargetAllocationValid)
            }
        }
        .navigationTitle("策略")
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") {
                    focusedInput = nil
                }
            }
        }
        .confirmationDialog("策略预览", isPresented: $showPreviewConfirm, titleVisibility: .visible) {
            Button("是，执行并添加记录") {
                confirmAndApplyPolicy()
            }
            Button("否，取消", role: .cancel) {
                clearPendingPreview()
            }
        } message: {
            Text(previewMessage)
        }
        .alert("策略执行结果", isPresented: $showResult) {
            Button("好的", role: .cancel) {}
        } message: {
            Text(resultMessage)
        }
    }

    @ViewBuilder
    private func amountField(_ title: String, text: Binding<String>, field: InputField) -> some View {
        TextField(title, text: text)
            .keyboardType(.decimalPad)
            .textContentType(.none)
            .autocorrectionDisabled(true)
            .focused($focusedInput, equals: field)
    }

    private func runPolicy(_ action: PolicyAction, fund: Double) {
        focusedInput = nil

        guard let preview = dataManager.previewPolicyTrade(action: action, fund: fund) else {
            resultMessage = "执行失败：请检查资金输入或当前资产状态。"
            showResult = true
            return
        }

        pendingPreview = preview
        pendingAction = action
        previewMessage = buildResultMessage(from: preview, title: "以下为策略预览，是否确认执行？")
        showPreviewConfirm = true
    }

    private func confirmAndApplyPolicy() {
        guard let preview = pendingPreview, let action = pendingAction else { return }
        dataManager.applyPolicyTrade(preview, date: actionDate)

        switch action {
        case .equalBuy:
            equalBuyFund = ""
        case .smartInjection:
            smartInjectionFund = ""
        case .smartAutoTrade:
            smartAutoFund = ""
        case .fullRebalance:
            break
        }

        resultMessage = buildResultMessage(from: preview, title: "策略已执行，记录已添加。")
        showResult = true
        clearPendingPreview()
    }

    private func clearPendingPreview() {
        pendingPreview = nil
        pendingAction = nil
        previewMessage = ""
    }

    private func buildResultMessage(from result: PolicyTradePreview, title: String) -> String {
        var lines = [
            title,
            "----------------",
            result.strategyName,
            "股票: \(String(format: "%.2f", result.stock))",
            "债券: \(String(format: "%.2f", result.bond))",
            "黄金: \(String(format: "%.2f", result.gold))",
            "现金: \(String(format: "%.2f", result.cash))"
        ]

        if let theta = result.theta, let threshold = result.threshold {
            lines.append("Theta: \(String(format: "%.4f", theta))")
            lines.append("阈值: \(String(format: "%.2f", threshold))")
        }

        return lines.joined(separator: "\n")
    }

    private func parseAmount(_ text: String) -> Double {
        let sanitized = text
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "，", with: "")
            .replacingOccurrences(of: "¥", with: "")
            .replacingOccurrences(of: "￥", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return Double(sanitized) ?? 0
    }

    private func signedFund(from text: String, direction: FundDirection) -> Double {
        let amount = parseAmount(text)
        return direction == .deposit ? amount : -amount
    }
}
