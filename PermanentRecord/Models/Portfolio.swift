//
//  Portfolio.swift
//  永久投资组合
//

import Foundation
import CoreData

struct Portfolio {
    var id: UUID
    var name: String
    var totalAssets: Double
    var totalReturn: Double
    var returnRate: Double
    var lastUpdateDate: Date?

    init(id: UUID = UUID(), name: String, totalAssets: Double = 0, totalReturn: Double = 0, returnRate: Double = 0, lastUpdateDate: Date? = nil) {
        self.id = id
        self.name = name
        self.totalAssets = totalAssets
        self.totalReturn = totalReturn
        self.returnRate = returnRate
        self.lastUpdateDate = lastUpdateDate
    }

    // 格式化总资产
    var formattedTotalAssets: String {
        return String(format: "¥%.2f", totalAssets)
    }

    // 格式化总收益
    var formattedTotalReturn: String {
        let sign = totalReturn >= 0 ? "+" : ""
        return String(format: "¥%.2f", totalReturn)
    }

    // 格式化收益率
    var formattedReturnRate: String {
        let sign = returnRate >= 0 ? "+" : ""
        return String(format: "%@%.2f%%", sign, returnRate)
    }

    // 格式化更新日期
    var formattedLastUpdate: String {
        guard let date = lastUpdateDate else { return "从未更新" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
