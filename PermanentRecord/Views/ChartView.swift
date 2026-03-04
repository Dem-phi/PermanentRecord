//
//  ChartView.swift
//  图表视图
//

import SwiftUI
import Charts

struct ChartView: View {
    @EnvironmentObject var dataManager: DataManager

    @State private var selectedChartType: ChartType = .returnRate
    @State private var timeRange: TimeRange = .all
    @State private var selectedRecord: Record?

    enum ChartType: String, CaseIterable {
        case returnRate = "收益率"
        case assetValue = "资产市值"
        case allocation = "资产比例"
    }

    enum TimeRange: String, CaseIterable {
        case all = "全部"
        case recent = "最近30天"
        case recent3m = "最近3个月"
    }

    struct AllocationData: Identifiable {
        let id = UUID()
        let assetType: String
        let value: Double
    }

    private let assetTypes = ["股票", "债券", "黄金", "现金"]

    var filteredRecords: [Record] {
        let records = dataManager.records.sorted { $0.date < $1.date }

        switch timeRange {
        case .all:
            return records
        case .recent:
            guard let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) else {
                return records
            }
            return records.filter { $0.date >= thirtyDaysAgo }
        case .recent3m:
            guard let threeMonthsAgo = Calendar.current.date(byAdding: .month, value: -3, to: Date()) else {
                return records
            }
            return records.filter { $0.date >= threeMonthsAgo }
        }
    }

    private var allocationData: [AllocationData] {
        if let latestRecord = filteredRecords.last {
            return [
                AllocationData(assetType: "股票", value: latestRecord.stockAllocation),
                AllocationData(assetType: "债券", value: latestRecord.bondAllocation),
                AllocationData(assetType: "黄金", value: latestRecord.goldAllocation),
                AllocationData(assetType: "现金", value: latestRecord.cashAllocation)
            ]
        }

        let stock = dataManager.currentAllocationPercent(for: .stock)
        let bond = dataManager.currentAllocationPercent(for: .bond)
        let gold = dataManager.currentAllocationPercent(for: .gold)
        let cash = dataManager.currentAllocationPercent(for: .cash)

        let total = stock + bond + gold + cash
        guard total > 0 else { return [] }

        return [
            AllocationData(assetType: "股票", value: stock),
            AllocationData(assetType: "债券", value: bond),
            AllocationData(assetType: "黄金", value: gold),
            AllocationData(assetType: "现金", value: cash)
        ]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                chartTypePicker
                timeRangePicker

                if selectedChartType == .returnRate {
                    returnRateChart
                }

                if selectedChartType == .assetValue {
                    assetValueChart
                }

                if selectedChartType == .allocation {
                    allocationChart
                }
            }
            .padding()
        }
    }

    private var chartTypePicker: some View {
        Picker("", selection: $selectedChartType) {
            ForEach(ChartType.allCases, id: \.self) { chartType in
                Text(chartType.rawValue)
            }
        }
        .pickerStyle(.segmented)
    }

    private var timeRangePicker: some View {
        Picker("", selection: $timeRange) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Text(range.rawValue)
            }
        }
        .pickerStyle(.menu)
    }

    private var returnRateChart: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("收益率趋势")
                .font(.headline)

            if filteredRecords.isEmpty {
                Text("暂无数据")
                    .foregroundColor(.secondary)
            } else {
                Chart {
                    ForEach(filteredRecords, id: \.id) { record in
                        LineMark(
                            x: .value("日期", record.date),
                            y: .value("收益率", returnRate(for: record))
                        )
                        .foregroundStyle(.blue)
                        .symbol(.circle)
                    }

                    if let selected = selectedRecord {
                        RuleMark(x: .value("日期", selected.date))
                            .foregroundStyle(.gray.opacity(0.4))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .annotation(position: .top, alignment: .leading) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(selected.formattedDate)
                                    Text(String(format: "收益率 %.2f%%", returnRate(for: selected)))
                                }
                                .font(.caption2)
                                .padding(6)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
                            }
                    }
                }
                .frame(height: 250)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) {
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisTick()
                        if let rate = value.as(Double.self) {
                            AxisValueLabel("\(Int(rate))%")
                        }
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        updateSelection(at: value.location, proxy: proxy, geometry: geometry)
                                    }
                                    .onEnded { value in
                                        updateSelection(at: value.location, proxy: proxy, geometry: geometry)
                                    }
                            )
                    }
                }

                if selectedRecord != nil {
                    Button("还原") {
                        selectedRecord = nil
                    }
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
                }
            }
        }
    }

    private var assetValueChart: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("资产市值趋势")
                .font(.headline)

            if filteredRecords.isEmpty {
                Text("暂无数据")
                    .foregroundColor(.secondary)
            } else {
                Chart {
                    ForEach(assetTypes, id: \.self) { assetType in
                        ForEach(filteredRecords, id: \.id) { record in
                            LineMark(
                                x: .value("日期", record.date),
                                y: .value("市值", getValue(for: assetType, record: record))
                            )
                            .foregroundStyle(by: .value("资产", assetType))
                            .symbol(by: .value("资产", assetType))
                        }
                    }

                    if let selected = selectedRecord {
                        RuleMark(x: .value("日期", selected.date))
                            .foregroundStyle(.gray.opacity(0.4))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .annotation(position: .top, alignment: .leading) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(selected.formattedDate)
                                    Text(String(format: "股票 ¥%.2f", selected.stockValue))
                                    Text(String(format: "债券 ¥%.2f", selected.bondValue))
                                    Text(String(format: "黄金 ¥%.2f", selected.goldValue))
                                    Text(String(format: "现金 ¥%.2f", selected.cashValue))
                                }
                                .font(.caption2)
                                .padding(6)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
                            }
                    }
                }
                .frame(height: 250)
                .chartForegroundStyleScale([
                    "股票": .red,
                    "债券": .blue,
                    "黄金": .orange,
                    "现金": .green
                ])
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) {
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisTick()
                        if let amount = value.as(Double.self) {
                            AxisValueLabel("¥\(Int(amount))")
                        }
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        updateSelection(at: value.location, proxy: proxy, geometry: geometry)
                                    }
                                    .onEnded { value in
                                        updateSelection(at: value.location, proxy: proxy, geometry: geometry)
                                    }
                            )
                    }
                }

                if selectedRecord != nil {
                    Button("还原") {
                        selectedRecord = nil
                    }
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
                }
            }
        }
    }

    private var allocationChart: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("资产比例分布")
                .font(.headline)

            if allocationData.isEmpty {
                Text("暂无数据")
                    .foregroundColor(.secondary)
            } else {
                Chart(allocationData) { item in
                    BarMark(
                        x: .value("资产", item.assetType),
                        y: .value("比例", item.value)
                    )
                    .foregroundStyle(by: .value("资产", item.assetType))
                    .annotation(position: .top) {
                        Text(String(format: "%.1f%%", item.value))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(height: 250)
                .chartForegroundStyleScale([
                    "股票": .red,
                    "债券": .blue,
                    "黄金": .orange,
                    "现金": .green
                ])
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisTick()
                        if let ratio = value.as(Double.self) {
                            AxisValueLabel("\(Int(ratio))%")
                        }
                    }
                }
            }
        }
    }

    private func returnRate(for record: Record) -> Double {
        guard record.totalPrincipal > 0 else { return 0 }
        return (record.totalReturn / record.totalPrincipal) * 100
    }

    private func getValue(for assetType: String, record: Record) -> Double {
        switch assetType {
        case "股票":
            return record.stockValue
        case "债券":
            return record.bondValue
        case "黄金":
            return record.goldValue
        case "现金":
            return record.cashValue
        default:
            return 0
        }
    }

    private func nearestRecord(to date: Date) -> Record? {
        filteredRecords.min {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        }
    }

    private func updateSelection(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        let plotFrame = geometry[proxy.plotAreaFrame]
        guard plotFrame.contains(location) else { return }

        let xPosition = location.x - plotFrame.origin.x
        guard
            let date: Date = proxy.value(atX: xPosition),
            let nearest = nearestRecord(to: date),
            let nearestX = proxy.position(forX: nearest.date)
        else {
            return
        }

        if abs(nearestX - xPosition) <= 18 {
            selectedRecord = nearest
        }
    }
}
