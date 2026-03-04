//
//  Record.swift
//  历史记录模型
//

import Foundation

struct Record: Identifiable {
    var id: UUID
    var date: Date
    var stockValue: Double
    var bondValue: Double
    var goldValue: Double
    var cashValue: Double
    var stockPrincipal: Double
    var bondPrincipal: Double
    var goldPrincipal: Double
    var cashPrincipal: Double

    init(id: UUID = UUID(), date: Date = Date(), stockValue: Double = 0, bondValue: Double = 0, goldValue: Double = 0, cashValue: Double = 0, stockPrincipal: Double = 0, bondPrincipal: Double = 0, goldPrincipal: Double = 0, cashPrincipal: Double = 0) {
        self.id = id
        self.date = date
        self.stockValue = stockValue
        self.bondValue = bondValue
        self.goldValue = goldValue
        self.cashValue = cashValue
        self.stockPrincipal = stockPrincipal
        self.bondPrincipal = bondPrincipal
        self.goldPrincipal = goldPrincipal
        self.cashPrincipal = cashPrincipal
    }

    // 计算总资产
    var totalValue: Double {
        return stockValue + bondValue + goldValue + cashValue
    }

    // 计算总本金
    var totalPrincipal: Double {
        return stockPrincipal + bondPrincipal + goldPrincipal + cashPrincipal
    }

    // 计算总收益
    var totalReturn: Double {
        return totalValue - totalPrincipal
    }

    // 格式化日期
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    // 格式化日期（中文）
    var formattedDateCN: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM月dd日"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }

    // 格式化各项市值
    var formattedStockValue: String {
        return String(format: "¥%.2f", stockValue)
    }
    var formattedBondValue: String {
        return String(format: "¥%.2f", bondValue)
    }
    var formattedGoldValue: String {
        return String(format: "¥%.2f", goldValue)
    }
    var formattedCashValue: String {
        return String(format: "¥%.2f", cashValue)
    }

    // 格式化总资产
    var formattedTotalValue: String {
        return String(format: "¥%.2f", totalValue)
    }

    // 格式化总收益
    var formattedTotalReturn: String {
        let sign = totalReturn >= 0 ? "+" : ""
        return String(format: "¥%.2f", totalReturn)
    }

    // 计算各项收益
    var stockReturn: Double {
        return stockValue - stockPrincipal
    }
    var bondReturn: Double {
        return bondValue - bondPrincipal
    }
    var goldReturn: Double {
        return goldValue - goldPrincipal
    }
    var cashReturn: Double {
        return cashValue - cashPrincipal
    }

    // 计算资产比例
    var stockAllocation: Double {
        return totalValue > 0 ? (stockValue / totalValue * 100) : 0
    }
    var bondAllocation: Double {
        return totalValue > 0 ? (bondValue / totalValue * 100) : 0
    }
    var goldAllocation: Double {
        return totalValue > 0 ? (goldValue / totalValue * 100) : 0
    }
    var cashAllocation: Double {
        return totalValue > 0 ? (cashValue / totalValue * 100) : 0
    }
}
