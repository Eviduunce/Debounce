//
//  ChatterEvent.swift
//  Debounce
//
//  Created by Timo Leisengang on 07.10.25.
//

import Foundation
import CoreGraphics

/// Represents a blocked chatter event for logging
struct ChatterEvent: Identifiable {
    let id = UUID()
    let timestamp: Date
    let keyCode: CGKeyCode
    let keyName: String
    let timeDelta: UInt64 // milliseconds since last press
}
