//
//  Keypair.swift
//  SolanaWeb3
//
//  Created by Scott on 2022/3/20.
//

import Foundation
import TweetNacl

/// Keypair signer
public struct Signer {
    public let publicKey: PublicKey
    public let secretKey: Data
}

/// Ed25519 Keypair
public struct Ed25519Keypair {
    public let publicKey: Data
    public let secretKey: Data
}

/// An account keypair used for signing transactions.
public struct Keypair {

    let keypair: Ed25519Keypair

    /// Create a new keypair instance.
    /// Generate random keypair if no {@link Ed25519Keypair} is provided.
    ///
    /// - Parameters:
    ///   - keypair: ed25519 keypair
    public init(keypair: Ed25519Keypair? = nil) throws {
        if let keypair = keypair {
            self.keypair = keypair
        } else {
            let (publicKey, secretKey) = try NaclSign.KeyPair.keyPair()
            self.keypair = Ed25519Keypair(publicKey: publicKey, secretKey: secretKey)
        }
    }

    /// Create a keypair from a raw secret key byte array.
    ///
    /// This method should only be used to recreate a keypair from a previously
    /// generated secret key. Generating keypairs from a random seed should be done
    /// with the {@link Keypair.fromSeed} method.
    ///
    /// - Parameters:
    ///   - secretKey: secret key data
    ///   - options: skip secret key validation
    init(secretKey: Data, options: InitOption? = nil) throws {
        let (publicKey, secretKey) = try NaclSign.KeyPair.keyPair(fromSecretKey: secretKey)
        if let options = options, options.skipValidation == false {
            // TODO: not finished
        }
        self.keypair = Ed25519Keypair(publicKey: publicKey, secretKey: secretKey)
    }

    /// Generate a keypair from a 32 byte seed.
    ///
    /// - Parameters:
    ///   - seed: seed byte array
    public init(seed: Data) throws {
        let (publicKey, secretKey) = try NaclSign.KeyPair.keyPair(fromSeed: seed)
        self.keypair = Ed25519Keypair(publicKey: publicKey, secretKey: secretKey)
    }

    /// The public key for this keypair
    public var publicKey: PublicKey {
        get throws {
            try PublicKey(keypair.publicKey)
        }
    }

    /// The raw secret key for this keypair
    public var secretKey: Data {
        keypair.secretKey
    }
}

// MARK: - Option
public extension Keypair {

    struct InitOption {
        let skipValidation: Bool
    }
}
