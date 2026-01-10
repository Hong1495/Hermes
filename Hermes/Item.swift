//
//  Item.swift
//  Hermes
//
//  Created by 斯威特哈尼 on 2026/1/10.
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
