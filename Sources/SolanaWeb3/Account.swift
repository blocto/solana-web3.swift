//
//  Account.swift
//  SolanaWeb3
//
//  Created by Scott on 2022/3/11.
//

import Foundation
import TweetNacl

public struct Account {

    private let keyPair: KeyPair

    public var publicKey: PublicKey {
        get throws {
            try PublicKey(keyPair.publicKey)
        }
    }

    public var secretKey: Data {
        keyPair.secretKey
    }

    public init() throws {
        let (publicKey, secretKey) = try NaclSign.KeyPair.keyPair()
        self.keyPair = KeyPair(publicKey: publicKey, secretKey: secretKey)
    }

    public init(secretKey: Data) throws {
        let (publicKey, secretKey) = try NaclSign.KeyPair.keyPair(fromSecretKey: secretKey)
        self.keyPair = KeyPair(publicKey: publicKey, secretKey: secretKey)
    }

    public init(secretKey: [UInt8]) throws {
        try self.init(secretKey: Data(secretKey))
    }
}

// MARK: - KeyPair
extension Account {

    private struct KeyPair {
        let publicKey: Data
        let secretKey: Data
    }
}
