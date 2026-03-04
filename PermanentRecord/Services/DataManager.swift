//
//  DataManager.swift
//  数据管理服务
//

import Foundation
import SwiftUI
import Combine

enum PolicyAction: String, CaseIterable, Identifiable {
    case equalBuy = "按比例买入"
    case smartInjection = "智能填坑/削峰"
    case fullRebalance = "强制再平衡"
    case smartAutoTrade = "智能买卖决策"

    var id: String { rawValue }
}

struct PolicyTradePreview {
    let action: PolicyAction
    let stock: Double
    let bond: Double
    let gold: Double
    let cash: Double
    let strategyName: String
    let theta: Double?
    let threshold: Double?
}

@MainActor
class DataManager: ObservableObject {
    @Published var assets: [Asset] = []
    @Published var records: [Record] = []
    @Published var portfolio: Portfolio?
    @Published var rebalanceThresholdPercent: Double = 10 {
        didSet {
            saveRebalanceSettings()
        }
    }
    @Published var targetStockPercent: Double = 25 {
        didSet { saveRebalanceSettings() }
    }
    @Published var targetBondPercent: Double = 25 {
        didSet { saveRebalanceSettings() }
    }
    @Published var targetGoldPercent: Double = 25 {
        didSet { saveRebalanceSettings() }
    }
    @Published var targetCashPercent: Double = 25 {
        didSet { saveRebalanceSettings() }
    }

    private let userDefaults = UserDefaults.standard
    private let rebalanceThresholdKey = "rebalanceThresholdPercent"
    private let targetStockPercentKey = "targetStockPercent"
    private let targetBondPercentKey = "targetBondPercent"
    private let targetGoldPercentKey = "targetGoldPercent"
    private let targetCashPercentKey = "targetCashPercent"

    // 预设资产
    private let defaultAssets: [(type: AssetType, name: String, code: String)] = [
        (.stock, "中证A500ETF", "159338"),
        (.bond, "华泰保兴安悦债券A", "007540"),
        (.gold, "黄金ETF华夏", "518850"),
        (.cash, "平安灵活宝", "000000")
    ]

    init() {
        loadData()
    }

    // 加载数据
    func loadData() {
        loadRebalanceSettings()

        // 加载资产数据
        if let assetsData = userDefaults.array(forKey: "assets") as? [[String: Any]] {
            assets = assetsData.compactMap { data -> Asset? in
                guard let type = data["type"] as? String,
                      let name = data["name"] as? String,
                      let code = data["code"] as? String,
                      let currentValue = data["currentValue"] as? Double,
                      let principal = data["principal"] as? Double else {
                    return nil
                }
                let assetType = AssetType(rawValue: type) ?? .stock
                return Asset(type: assetType, name: name, code: code, currentValue: currentValue, principal: principal)
            }
        } else {
            // 初始化默认资产
            assets = defaultAssets.map { (type, name, code) in
                Asset(type: type, name: name, code: code, currentValue: 0, principal: 0)
            }
        }

        // 加载历史记录
        if let recordsData = userDefaults.array(forKey: "records") as? [[String: Any]] {
            records = recordsData.compactMap { data -> Record? in
                guard let dateString = data["date"] as? String,
                      let stockValue = data["stockValue"] as? Double,
                      let bondValue = data["bondValue"] as? Double,
                      let goldValue = data["goldValue"] as? Double,
                      let cashValue = data["cashValue"] as? Double,
                      let stockPrincipal = data["stockPrincipal"] as? Double,
                      let bondPrincipal = data["bondPrincipal"] as? Double,
                      let goldPrincipal = data["goldPrincipal"] as? Double,
                      let cashPrincipal = data["cashPrincipal"] as? Double else {
                    return nil
                }
                guard let date = ISO8601DateFormatter().date(from: dateString) else {
                    return nil
                }
                return Record(
                    date: date,
                    stockValue: stockValue,
                    bondValue: bondValue,
                    goldValue: goldValue,
                    cashValue: cashValue,
                    stockPrincipal: stockPrincipal,
                    bondPrincipal: bondPrincipal,
                    goldPrincipal: goldPrincipal,
                    cashPrincipal: cashPrincipal
                )
            }
        }

        syncAssetsWithLatestRecord()
        updatePortfolio()
    }

    // 更新投资组合
    func updatePortfolio() {
        let totalAssets = assets.reduce(0) { $0 + $1.currentValue }
        let totalPrincipal = assets.reduce(0) { $0 + $1.principal }
        let totalReturn = totalAssets - totalPrincipal
        let returnRate = totalPrincipal > 0 ? (totalReturn / totalPrincipal) * 100 : 0
        let latestDate = records.first?.date

        portfolio = Portfolio(
            name: "永久投资组合",
            totalAssets: totalAssets,
            totalReturn: totalReturn,
            returnRate: returnRate,
            lastUpdateDate: latestDate
        )
    }

    // 保存资产数据
    func saveAssets() {
        let assetsData = assets.map { asset -> [String: Any] in
            return [
                "type": asset.type.rawValue,
                "name": asset.name,
                "code": asset.code,
                "currentValue": asset.currentValue,
                "principal": asset.principal
            ]
        }
        userDefaults.set(assetsData, forKey: "assets")
    }

    // 保存历史记录
    func saveRecords() {
        let recordsData = records.map { record -> [String: Any] in
            let formatter = ISO8601DateFormatter()
            return [
                "date": formatter.string(from: record.date),
                "stockValue": record.stockValue,
                "bondValue": record.bondValue,
                "goldValue": record.goldValue,
                "cashValue": record.cashValue,
                "stockPrincipal": record.stockPrincipal,
                "bondPrincipal": record.bondPrincipal,
                "goldPrincipal": record.goldPrincipal,
                "cashPrincipal": record.cashPrincipal
            ]
        }
        userDefaults.set(recordsData, forKey: "records")
    }

    // 添加新记录
    func addRecord(_ record: Record) {
        records.insert(record, at: 0)
        saveRecords()
        syncAssetsWithLatestRecord()
        saveAssets()
        updatePortfolio()
    }

    // 更新记录
    func updateRecord(_ record: Record) {
        if let index = records.firstIndex(where: { $0.id == record.id }) {
            records[index] = record
            saveRecords()
        }
        syncAssetsWithLatestRecord()
        saveAssets()
        updatePortfolio()
    }

    // 删除记录
    func deleteRecord(_ record: Record) {
        records.removeAll { $0.id == record.id }
        saveRecords()
        syncAssetsWithLatestRecord()
        saveAssets()
        updatePortfolio()
    }

    // 更新资产
    func updateAsset(_ asset: Asset) {
        if let index = assets.firstIndex(where: { $0.id == asset.id }) {
            assets[index] = asset
            saveAssets()
        }
        updatePortfolio()
    }

    func targetAllocationPercent(for type: AssetType) -> Double {
        switch type {
        case .stock: return targetStockPercent
        case .bond: return targetBondPercent
        case .gold: return targetGoldPercent
        case .cash: return targetCashPercent
        }
    }

    func currentAllocationPercent(for type: AssetType) -> Double {
        let total = assets.reduce(0.0) { $0 + $1.currentValue }
        guard total > 0 else { return 0 }
        let value = assets.first(where: { $0.type == type })?.currentValue ?? 0
        return (value / total) * 100
    }

    func allocationDeviationPercent(for type: AssetType) -> Double {
        currentAllocationPercent(for: type) - targetAllocationPercent(for: type)
    }

    func rebalanceStatus(for type: AssetType) -> String {
        abs(allocationDeviationPercent(for: type)) > rebalanceThresholdPercent ? "⚠️平衡" : "✅ 正常"
    }

    var targetTotalPercent: Double {
        targetStockPercent + targetBondPercent + targetGoldPercent + targetCashPercent
    }

    var isTargetAllocationValid: Bool {
        abs(targetTotalPercent - 100) < 0.0001
    }

    var targetAllocationValidationMessage: String? {
        guard !isTargetAllocationValid else { return nil }
        return String(format: "目标配置比例设置错误：当前合计 %.1f%%，必须等于 100%%。", targetTotalPercent)
    }

    // 执行 Policy 宏策略
    func executePolicyTrade(action: PolicyAction, fund: Double, date: Date = Date()) -> PolicyTradePreview? {
        guard let preview = previewPolicyTrade(action: action, fund: fund) else { return nil }
        applyPolicyTrade(preview, date: date)
        return preview
    }

    // 仅预览 Policy 结果，不落库
    func previewPolicyTrade(action: PolicyAction, fund: Double) -> PolicyTradePreview? {
        computePolicyTrade(action: action, fund: fund)
    }

    // 应用已确认的策略预览并写入记录
    func applyPolicyTrade(_ preview: PolicyTradePreview, date: Date = Date()) {
        let current = currentAssetState()
        let stockValue = max(0, current.stockValue + preview.stock)
        let bondValue = max(0, current.bondValue + preview.bond)
        let goldValue = max(0, current.goldValue + preview.gold)
        let cashValue = max(0, current.cashValue + preview.cash)

        let stockPrincipal = max(0, current.stockPrincipal + preview.stock)
        let bondPrincipal = max(0, current.bondPrincipal + preview.bond)
        let goldPrincipal = max(0, current.goldPrincipal + preview.gold)
        let cashPrincipal = max(0, current.cashPrincipal + preview.cash)

        let newRecord = Record(
            date: date,
            stockValue: stockValue,
            bondValue: bondValue,
            goldValue: goldValue,
            cashValue: cashValue,
            stockPrincipal: stockPrincipal,
            bondPrincipal: bondPrincipal,
            goldPrincipal: goldPrincipal,
            cashPrincipal: cashPrincipal
        )

        addRecord(newRecord)
    }

    // 导出数据为 CSV
    func exportToCSV() -> URL? {
        let fileName = "永久投资组合记录_\(Date().timeIntervalSince1970).csv"

        var csvContent = "日期,股票市值,债券市值,黄金市值,现金市值,总资产,股票本金,债券本金,黄金本金,现金本金,总本金,总收益\n"

        for record in records {
            csvContent += "\(record.formattedDate),\(record.stockValue),\(record.bondValue),\(record.goldValue),\(record.cashValue),\(record.totalValue),\(record.stockPrincipal),\(record.bondPrincipal),\(record.goldPrincipal),\(record.cashPrincipal),\(record.totalPrincipal),\(record.totalReturn)\n"
        }

        guard let data = csvContent.data(using: .utf8) else { return nil }

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)

        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("导出失败: \(error)")
            return nil
        }
    }

    // 导出数据为 JSON
    func exportToJSON() -> URL? {
        let fileName = "永久投资组合记录_\(Date().timeIntervalSince1970).json"

        let recordsData = records.map { record -> [String: Any] in
            let formatter = ISO8601DateFormatter()
            return [
                "date": formatter.string(from: record.date),
                "stockValue": record.stockValue,
                "bondValue": record.bondValue,
                "goldValue": record.goldValue,
                "cashValue": record.cashValue,
                "stockPrincipal": record.stockPrincipal,
                "bondPrincipal": record.bondPrincipal,
                "goldPrincipal": record.goldPrincipal,
                "cashPrincipal": record.cashPrincipal
            ]
        }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: ["records": recordsData], options: .prettyPrinted)
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent(fileName)
            try jsonData.write(to: fileURL)
            return fileURL
        } catch {
            print("导出失败: \(error)")
            return nil
        }
    }

    // 清除所有数据
    func clearAllData() {
        assets = []
        records = []
        portfolio = nil
        userDefaults.removeObject(forKey: "assets")
        userDefaults.removeObject(forKey: "records")
    }

    private func syncAssetsWithLatestRecord() {
        // Always treat the most recently inserted record as current state.
        let latestRecord = records.first

        for index in assets.indices {
            switch assets[index].type {
            case .stock:
                assets[index].currentValue = latestRecord?.stockValue ?? 0
                assets[index].principal = latestRecord?.stockPrincipal ?? 0
            case .bond:
                assets[index].currentValue = latestRecord?.bondValue ?? 0
                assets[index].principal = latestRecord?.bondPrincipal ?? 0
            case .gold:
                assets[index].currentValue = latestRecord?.goldValue ?? 0
                assets[index].principal = latestRecord?.goldPrincipal ?? 0
            case .cash:
                assets[index].currentValue = latestRecord?.cashValue ?? 0
                assets[index].principal = latestRecord?.cashPrincipal ?? 0
            }
        }
    }

    private func loadRebalanceSettings() {
        if userDefaults.object(forKey: rebalanceThresholdKey) != nil {
            rebalanceThresholdPercent = userDefaults.double(forKey: rebalanceThresholdKey)
        } else {
            rebalanceThresholdPercent = 10
        }

        targetStockPercent = userDefaults.object(forKey: targetStockPercentKey) != nil ? userDefaults.double(forKey: targetStockPercentKey) : 25
        targetBondPercent = userDefaults.object(forKey: targetBondPercentKey) != nil ? userDefaults.double(forKey: targetBondPercentKey) : 25
        targetGoldPercent = userDefaults.object(forKey: targetGoldPercentKey) != nil ? userDefaults.double(forKey: targetGoldPercentKey) : 25
        targetCashPercent = userDefaults.object(forKey: targetCashPercentKey) != nil ? userDefaults.double(forKey: targetCashPercentKey) : 25
    }

    private func saveRebalanceSettings() {
        userDefaults.set(rebalanceThresholdPercent, forKey: rebalanceThresholdKey)
        userDefaults.set(targetStockPercent, forKey: targetStockPercentKey)
        userDefaults.set(targetBondPercent, forKey: targetBondPercentKey)
        userDefaults.set(targetGoldPercent, forKey: targetGoldPercentKey)
        userDefaults.set(targetCashPercent, forKey: targetCashPercentKey)
    }

    private func computePolicyTrade(action: PolicyAction, fund: Double) -> PolicyTradePreview? {
        let current = currentAssetState()
        let cur = [current.stockValue, current.bondValue, current.goldValue, current.cashValue]
        let target = normalizedTargetFractions()
        let total = cur.reduce(0, +)

        switch action {
        case .equalBuy:
            guard fund > 0 else { return nil }
            let adj = target.map { fund * $0 }
            return PolicyTradePreview(
                action: action,
                stock: adj[0],
                bond: adj[1],
                gold: adj[2],
                cash: adj[3],
                strategyName: "按目标比例平均买入",
                theta: nil,
                threshold: nil
            )

        case .smartInjection:
            guard fund != 0 else { return nil }
            let adj = smartInjectionAdjustments(current: cur, target: target, fund: fund)
            return PolicyTradePreview(
                action: action,
                stock: adj[0],
                bond: adj[1],
                gold: adj[2],
                cash: adj[3],
                strategyName: fund > 0 ? "优先填坑买入" : "优先削峰卖出",
                theta: nil,
                threshold: nil
            )

        case .fullRebalance:
            guard total > 0 else { return nil }
            let targetAmounts = target.map { total * $0 }
            let diff = zip(targetAmounts, cur).map { $0 - $1 }
            return PolicyTradePreview(
                action: action,
                stock: diff[0],
                bond: diff[1],
                gold: diff[2],
                cash: diff[3],
                strategyName: "强制再平衡",
                theta: nil,
                threshold: nil
            )

        case .smartAutoTrade:
            guard fund != 0, total > 0 else { return nil }
            let curPct = cur.map { $0 / total }
            let theta = zip(curPct, target).reduce(0.0) { $0 + abs($1.0 - $1.1) }
            let threshold = total * theta
            let absFund = abs(fund)

            let strategyName: String
            let adj: [Double]

            if fund > 0 {
                if fund > threshold {
                    adj = target.map { fund * $0 }
                    strategyName = "大额存入: 按比例平均买入"
                } else {
                    adj = smartInjectionAdjustments(current: cur, target: target, fund: fund)
                    strategyName = "小额存入: 智能填坑"
                }
            } else {
                if absFund > threshold {
                    adj = target.map { fund * $0 }
                    strategyName = "大额取出: 按比例平均卖出"
                } else {
                    adj = smartInjectionAdjustments(current: cur, target: target, fund: fund)
                    strategyName = "小额取出: 智能削峰"
                }
            }

            return PolicyTradePreview(
                action: action,
                stock: adj[0],
                bond: adj[1],
                gold: adj[2],
                cash: adj[3],
                strategyName: strategyName,
                theta: theta,
                threshold: threshold
            )
        }
    }

    private func smartInjectionAdjustments(current cur: [Double], target: [Double], fund: Double) -> [Double] {
        let futureTotal = cur.reduce(0, +) + fund
        var gap = Array(repeating: 0.0, count: 4)
        for i in 0..<4 {
            gap[i] = (futureTotal * target[i]) - cur[i]
        }

        var finalAdj = Array(repeating: 0.0, count: 4)

        if fund > 0 {
            var totalGap = gap.filter { $0 > 0 }.reduce(0, +)
            if totalGap <= 0 {
                return target.map { fund * $0 }
            }

            if fund >= totalGap {
                let surplus = fund - totalGap
                for i in 0..<4 {
                    finalAdj[i] = max(gap[i], 0) + (surplus * target[i])
                }
            } else {
                for i in 0..<4 {
                    finalAdj[i] = gap[i] > 0 ? fund * (gap[i] / totalGap) : 0
                }
            }
        } else {
            let absFund = abs(fund)
            var totalGap = gap.filter { $0 < 0 }.reduce(0.0) { $0 + abs($1) }
            if totalGap <= 0 {
                return target.map { fund * $0 }
            }

            if absFund >= totalGap {
                let remainder = absFund - totalGap
                for i in 0..<4 {
                    finalAdj[i] = gap[i] < 0 ? gap[i] - (remainder * target[i]) : -(remainder * target[i])
                }
            } else {
                for i in 0..<4 {
                    finalAdj[i] = gap[i] < 0 ? fund * (abs(gap[i]) / totalGap) : 0
                }
            }
        }

        return finalAdj
    }

    private func currentAssetState() -> (
        stockValue: Double, bondValue: Double, goldValue: Double, cashValue: Double,
        stockPrincipal: Double, bondPrincipal: Double, goldPrincipal: Double, cashPrincipal: Double
    ) {
        func value(for type: AssetType) -> Double {
            assets.first(where: { $0.type == type })?.currentValue ?? 0
        }

        func principal(for type: AssetType) -> Double {
            assets.first(where: { $0.type == type })?.principal ?? 0
        }

        return (
            stockValue: value(for: .stock),
            bondValue: value(for: .bond),
            goldValue: value(for: .gold),
            cashValue: value(for: .cash),
            stockPrincipal: principal(for: .stock),
            bondPrincipal: principal(for: .bond),
            goldPrincipal: principal(for: .gold),
            cashPrincipal: principal(for: .cash)
        )
    }

    private func normalizedTargetFractions() -> [Double] {
        let percents = [targetStockPercent, targetBondPercent, targetGoldPercent, targetCashPercent]
        let sum = percents.reduce(0, +)
        guard sum > 0 else { return [0.25, 0.25, 0.25, 0.25] }
        return percents.map { $0 / sum }
    }
}
