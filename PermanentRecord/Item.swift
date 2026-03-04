//
//  Item.swift
//  PermanentRecord
//
//  Created by Demphi on 2026/3/4.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
