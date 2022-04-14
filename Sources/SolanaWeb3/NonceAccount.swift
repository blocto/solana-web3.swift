//
//  File.swift
//  SolanaWeb3
//
//  Created by Scott on 2022/3/30.
//

import Foundation

public struct NonceAccountLayout: BufferLayout {
    public let version: UInt32
    public let state: UInt32
    public let authorizedPublicKey: PublicKey
    public let nonce: PublicKey
    public let feeCalculator: FeeCalculator
}

public struct NonceAccount: Codable {
    public let authorizedPublicKey: PublicKey
    public let nonce: Blockhash
    public let feeCalculator: FeeCalculator

    enum CodingKeys: String, CodingKey {
        case authorizedPublicKey = "authorizedPubkey"
        case nonce
        case feeCalculator
    }
}
