//
//  RecordListView.swift
//  历史记录列表视图
//

import SwiftUI

struct RecordListView: View {
    @EnvironmentObject var dataManager: DataManager

    @State private var searchText = ""
    @State private var showingExportOptions = false
    @State private var exportURL: URL?

    var filteredRecords: [Record] {
        if searchText.isEmpty {
            return dataManager.records
        } else {
            return dataManager.records.filter { record in
                return record.formattedDate.contains(searchText) ||
                       String(format: "%.2f", record.totalValue).contains(searchText)
            }
        }
    }

    var body: some View {
        NavigationView {
            List {
                if filteredRecords.isEmpty {
                    Text("暂无记录")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(filteredRecords.reversed()) { record in
                        Section(header: Text(record.formattedDateCN)) {
                            NavigationLink(destination: RecordDetailView(record: record)) {
                                recordSummaryRow(record: record)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive, action: {
                                    deleteRecord(record)
                                }) {
                                    Image(systemName: "trash")
                                }
                            }
                            .contextMenu {
                                Button(role: .destructive, action: {
                                    deleteRecord(record)
                                }) {
                                    Text("删除")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("历史记录")
            .searchable(text: $searchText)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        showingExportOptions = true
                    }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .sheet(isPresented: $showingExportOptions) {
            exportOptionsSheet
        }
        .alert("导出文件", isPresented: Binding(
            get: { exportURL != nil },
            set: { if $0 { exportURL = nil } }
        )) {
            Button("在 App 中查看") {}
            Button("分享文件") {}
        } message: {
            Text("数据已准备好分享")
        }
    }

    // 导出选项
    private var exportOptionsSheet: some View {
        NavigationView {
            Form {
                Section(header: Text("导出格式")) {
                    Button(action: exportAsCSV) {
                        HStack {
                            Image(systemName: "doc.text")
                            Text("导出为 CSV")
                        }
                    }

                    Button(action: exportAsJSON) {
                        HStack {
                            Image(systemName: "doc.plaintext")
                            Text("导出为 JSON")
                        }
                    }
                }
            }
            .navigationTitle("导出选项")
        }
    }

    // 导出为 CSV
    private func exportAsCSV() {
        if let url = dataManager.exportToCSV() {
            exportURL = url
        }
    }

    // 导出为 JSON
    private func exportAsJSON() {
        if let url = dataManager.exportToJSON() {
            exportURL = url
        }
    }

    // 列表摘要行
    private func recordSummaryRow(record: Record) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("市值")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Text(record.formattedTotalValue)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("收益")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Text(record.formattedTotalReturn)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(record.totalReturn >= 0 ? .green : .red)

                    Text(String(format: "收益率 %.2f%%", totalReturnRate(for: record)))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(record.totalReturn >= 0 ? .green : .red)

                    Text(record.formattedDateCN)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // 删除记录
    private func deleteRecord(_ record: Record) {
        dataManager.deleteRecord(record)
    }

    private func totalReturnRate(for record: Record) -> Double {
        guard record.totalPrincipal > 0 else { return 0 }
        return (record.totalReturn / record.totalPrincipal) * 100
    }
}

struct RecordDetailView: View {
    let record: Record

    var body: some View {
        List {
            Section("总览") {
                detailRow("日期", record.formattedDate)
                detailRow("总市值", record.formattedTotalValue)
                detailRow("总本金", String(format: "¥%.2f", record.totalPrincipal))
                detailRow("总收益", String(format: "¥%.2f", record.totalReturn))
                detailRow("总收益率", String(format: "%.2f%%", returnRate(value: record.totalValue, principal: record.totalPrincipal)))
            }

            Section("股票") {
                assetDetailRows(value: record.stockValue, principal: record.stockPrincipal)
            }

            Section("债券") {
                assetDetailRows(value: record.bondValue, principal: record.bondPrincipal)
            }

            Section("黄金") {
                assetDetailRows(value: record.goldValue, principal: record.goldPrincipal)
            }

            Section("现金") {
                assetDetailRows(value: record.cashValue, principal: record.cashPrincipal)
            }
        }
        .navigationTitle("记录详情")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func assetDetailRows(value: Double, principal: Double) -> some View {
        detailRow("市值", String(format: "¥%.2f", value))
        detailRow("本金", String(format: "¥%.2f", principal))
        detailRow("收益", String(format: "¥%.2f", value - principal))
        detailRow("收益率", String(format: "%.2f%%", returnRate(value: value, principal: principal)))
    }

    @ViewBuilder
    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }

    private func returnRate(value: Double, principal: Double) -> Double {
        guard principal > 0 else { return 0 }
        return ((value - principal) / principal) * 100
    }
}
