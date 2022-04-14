//
//  Timing.swift
//  
//
//  Created by Scott on 2022/4/14.
//

import Foundation

public enum Timing {

    public static let numTicksPerSecond: TimeInterval = 160

    public static let defaultTicksPerSlot: TimeInterval = 64

    public static let numSlotsPerSecond: TimeInterval = numTicksPerSecond / defaultTicksPerSlot

    public static let msPerSlot: TimeInterval = 1000 / numSlotsPerSecond
}
