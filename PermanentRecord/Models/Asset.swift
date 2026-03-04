//
//  Asset.swift
//  资产模型
//

import Foundation

enum AssetType: String, CaseIterable {
    case stock = "股票"
    case bond = "债券"
    case gold = "黄金"
    case cash = "现金"

    var displayName: String {
        return rawValue
    }

    var color: String {
        switch self {
        case .stock: return "#E53E3E"
        case .bond: return "#3182CE"
        case .gold: return "#D69E2E"
        case .cash: return "#38A169"
        }
    }
}

struct Asset: Identifiable {
    var id: UUID
    var type: AssetType
    var name: String
    var code: String
    var currentValue: Double
    var principal: Double

    init(id: UUID = UUID(), type: AssetType = .stock, name: String, code: String, currentValue: Double = 0, principal: Double = 0) {
        self.id = id
        self.type = type
        self.name = name
        self.code = code
        self.currentValue = currentValue
        self.principal = principal
    }

    // 计算收益
    var returnValue: Double {
        return currentValue - principal
    }

    // 计算收益率
    var returnRate: Double {
        return principal > 0 ? ((currentValue - principal) / principal) * 100 : 0
    }

    // 格式化当前值
    var formattedCurrentValue: String {
        return String(format: "¥%.2f", currentValue)
    }

    // 格式化本金
    var formattedPrincipal: String {
        return String(format: "¥%.2f", principal)
    }

    // 格式化收益
    var formattedReturnValue: String {
        let value = currentValue - principal
        let sign = value >= 0 ? "+" : ""
        return String(format: "¥%.2f", value)
    }

    // 格式化收益率
    var formattedReturnRate: String {
        let rate = returnRate
        let sign = rate >= 0 ? "+" : ""
        return String(format: "%@%.2f%%", sign, rate)
    }
}
