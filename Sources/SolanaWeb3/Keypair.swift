//
//  Keypair.swift
//  SolanaWeb3
//
//  Created by Scott on 2022/3/20.
//

import Foundation
import TweetNacl

/// Keypair signer
public protocol Signer {
    var publicKey: PublicKey { get }
    var secretKey: Data { get }
}

/// Ed25519 Keypair
public struct Ed25519Keypair {
    public let publicKey: Data
    public let secretKey: Data
}

/// An account keypair used for signing transactions.
public struct Keypair: Signer {

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
        self.publicKey = try PublicKey(self.keypair.publicKey)
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
    public init(secretKey: Data, options: InitOption = InitOption()) throws {
        let (publicKey, secretKey) = try NaclSign.KeyPair.keyPair(fromSecretKey: secretKey)
        if options.skipValidation == false {
            let signData = "SolanaWeb3-validation-v1".data(using: .utf8) ?? Data()
            let signature = try NaclSign.signDetached(message: signData, secretKey: secretKey)
            if try NaclSign.signDetachedVerify(message: signData, sig: signature, publicKey: publicKey) == false {
                throw Error.providedSecretKeyIsInvalid
            }
        }
        self.keypair = Ed25519Keypair(publicKey: publicKey, secretKey: secretKey)
        self.publicKey = try PublicKey(keypair.publicKey)
    }

    /// Generate a keypair from a 32 byte seed.
    ///
    /// - Parameters:
    ///   - seed: seed byte array
    public init(seed: Data) throws {
        let (publicKey, secretKey) = try NaclSign.KeyPair.keyPair(fromSeed: seed)
        self.keypair = Ed25519Keypair(publicKey: publicKey, secretKey: secretKey)
        self.publicKey = try PublicKey(keypair.publicKey)
    }

    /// The public key for this keypair
    public let publicKey: PublicKey

    /// The raw secret key for this keypair
    public var secretKey: Data {
        keypair.secretKey
    }
}

// MARK: - Option
public extension Keypair {

    struct InitOption {
        let skipValidation: Bool

        public init(skipValidation: Bool = false) {
            self.skipValidation = skipValidation
        }
    }
}

// MARK: - Error
public extension Keypair {

    enum Error: Swift.Error {
        case providedSecretKeyIsInvalid
    }
}
