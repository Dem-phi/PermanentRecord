//
//  AddRecordView.swift
//  添加记录视图
//

import SwiftUI

struct AddRecordView: View {
    @EnvironmentObject var dataManager: DataManager

    @State private var stockValue: String = ""
    @State private var bondValue: String = ""
    @State private var goldValue: String = ""
    @State private var cashValue: String = ""

    @State private var stockPrincipal: String = ""
    @State private var bondPrincipal: String = ""
    @State private var goldPrincipal: String = ""
    @State private var cashPrincipal: String = ""

    @State private var selectedDate = Date()
    @State private var usePreviousValues = false
    @State private var isSaving = false
    @State private var showSavedHint = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case stockValue
        case bondValue
        case goldValue
        case cashValue
        case stockPrincipal
        case bondPrincipal
        case goldPrincipal
        case cashPrincipal
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("选择日期")) {
                    DatePicker("日期", selection: $selectedDate, displayedComponents: [.date])
                        .datePickerStyle(.compact)

                    Toggle("使用上一日的本金", isOn: $usePreviousValues)
                }

                Section(header: Text("今日市值")) {
                    amountField(title: "股票", text: $stockValue, field: .stockValue)
                    amountField(title: "债券", text: $bondValue, field: .bondValue)
                    amountField(title: "黄金", text: $goldValue, field: .goldValue)
                    amountField(title: "现金", text: $cashValue, field: .cashValue)
                }

                Section(header: Text("今日本金（可选）")) {
                    if usePreviousValues {
                        Text("留空时将自动使用上一日本金，手动填写可覆盖默认值。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    amountField(title: "股票", text: $stockPrincipal, field: .stockPrincipal)
                    amountField(title: "债券", text: $bondPrincipal, field: .bondPrincipal)
                    amountField(title: "黄金", text: $goldPrincipal, field: .goldPrincipal)
                    amountField(title: "现金", text: $cashPrincipal, field: .cashPrincipal)
                }

                Section {
                    Button(action: {
                        guard !isSaving else { return }
                        isSaving = true
                        focusedField = nil
                        Task { @MainActor in
                            // Let tap/keyboard state settle first to avoid gesture gate contention.
                            await Task.yield()
                            saveRecord()
                            showSaveHint()
                            isSaving = false
                        }
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text(isSaving ? "保存中..." : "保存记录")
                        }
                    }
                    .disabled(!canSave() || isSaving)
                    .frame(maxWidth: .infinity)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("添加记录")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") {
                        focusedField = nil
                    }
                }
            }
            .overlay(alignment: .top) {
                if showSavedHint {
                    Text("已保存")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }

    // 保存记录
    private func saveRecord() {
        let stockVal = parseAmount(stockValue)
        let bondVal = parseAmount(bondValue)
        let goldVal = parseAmount(goldValue)
        let cashVal = parseAmount(cashValue)

        var stockPrin = parseAmount(stockPrincipal)
        var bondPrin = parseAmount(bondPrincipal)
        var goldPrin = parseAmount(goldPrincipal)
        var cashPrin = parseAmount(cashPrincipal)

        // 可选使用上一日本金：仅在当前输入为空时回填默认值
        if usePreviousValues, let lastRecord = dataManager.records.first {
            if stockPrincipal.isEmpty { stockPrin = lastRecord.stockPrincipal }
            if bondPrincipal.isEmpty { bondPrin = lastRecord.bondPrincipal }
            if goldPrincipal.isEmpty { goldPrin = lastRecord.goldPrincipal }
            if cashPrincipal.isEmpty { cashPrin = lastRecord.cashPrincipal }
        }

        let newRecord = Record(
            date: selectedDate,
            stockValue: stockVal,
            bondValue: bondVal,
            goldValue: goldVal,
            cashValue: cashVal,
            stockPrincipal: stockPrin,
            bondPrincipal: bondPrin,
            goldPrincipal: goldPrin,
            cashPrincipal: cashPrin
        )

        dataManager.addRecord(newRecord)
        clearInputFields()
    }

    private func showSaveHint() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showSavedHint = true
        }

        Task {
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showSavedHint = false
                }
            }
        }
    }

    private func clearInputFields() {
        stockValue = ""
        bondValue = ""
        goldValue = ""
        cashValue = ""
        stockPrincipal = ""
        bondPrincipal = ""
        goldPrincipal = ""
        cashPrincipal = ""
    }

    // 检查是否可以保存
    private func canSave() -> Bool {
        let hasValue = [stockValue, bondValue, goldValue, cashValue].contains { !$0.isEmpty }
        return hasValue
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

    @ViewBuilder
    private func amountField(title: String, text: Binding<String>, field: Field) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("¥", text: text)
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .textContentType(.none)
                .autocorrectionDisabled(true)
                .focused($focusedField, equals: field)
        }
    }
}
