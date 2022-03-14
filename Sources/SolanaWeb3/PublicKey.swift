//
//  PublicKey.swift
//  SolanaWeb3
//
//  Created by Scott on 2022/3/11.
//

import Foundation

public struct PublicKey {

    private static let numberOfBytes = 32

    public let bytes: [UInt8]

    public init(_ string: String) throws {
        guard string.utf8.count >= Self.numberOfBytes else {
            throw Error.invalidPublicKeyInput
        }
        let bytes = Base58.decode(string)
        self.bytes = bytes
    }

    public init(_ data: Data) throws {
        guard data.count <= Self.numberOfBytes else {
            throw Error.invalidPublicKeyInput
        }
        self.bytes = [UInt8](data)
    }

    public init(_ bytes: [UInt8]) throws {
        guard bytes.count <= PublicKey.numberOfBytes else {
            throw Error.invalidPublicKeyInput
        }
        self.bytes = bytes
    }

    public var base58: String { Base58.encode(bytes) }

    public var data: Data { Data(bytes) }

    public static func createWithSeed() {

    }

}

// MARK: - Equatable
extension PublicKey: Equatable { }

// MARK: - CustomStringConvertible
extension PublicKey: CustomStringConvertible {

    public var description: String {
        base58
    }
}