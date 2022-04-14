//
//  FeeCalculator.swift
//  SolanaWeb3
//
//  Created by Scott on 2022/3/23.
//

import Foundation

public struct FeeCalculator: BufferLayout, Codable {
    public let lamportsPerSignature: UInt64
}
