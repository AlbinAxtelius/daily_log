//
//  Item.swift
//  daily_log
//
//  Created by Albin Axtelius on 2026-08-07.
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
