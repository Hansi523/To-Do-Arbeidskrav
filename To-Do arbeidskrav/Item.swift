//
//  Item.swift
//  To-Do arbeidskrav
//
//  Created by Hans Inge Paulshus on 28/09/2025.
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
