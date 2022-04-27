//
//  Account.swift
//  SolanaWeb3
//
//  Created by Scott on 2022/3/11.
//

import Foundation
import TweetNacl

public struct Account {

    public let publicKey: PublicKey

    public let secretKey: Data

    public init() throws {
        let (publicKey, secretKey) = try NaclSign.KeyPair.keyPair()
        self.publicKey = try PublicKey(publicKey)
        self.secretKey = secretKey
    }

    public init(secretKey: Data) throws {
        let (publicKey, secretKey) = try NaclSign.KeyPair.keyPair(fromSecretKey: secretKey)
        self.publicKey = try PublicKey(publicKey)
        self.secretKey = secretKey
    }

    public init(secretKey: [UInt8]) throws {
        try self.init(secretKey: Data(secretKey))
    }
}

// MARK: - Signer
extension Account: Signer { }
