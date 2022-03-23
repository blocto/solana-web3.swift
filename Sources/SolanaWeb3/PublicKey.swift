//
//  PublicKey.swift
//  SolanaWeb3
//
//  Created by Scott on 2022/3/11.
//

import Foundation
import CryptoSwift

public struct PublicKey {

    static let numberOfBytes = 32

    public let bytes: [UInt8]

    public init(_ string: String) throws {
        guard string.utf8.count >= Self.numberOfBytes else {
            throw Error.invalidPublicKeyInput
        }
        let bytes = Base58.decode(string)
        if bytes.count != Self.numberOfBytes {
            throw Error.invalidPublicKeyInput
        }
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

    /// Derive a public key from another key, a seed, and a program ID.
    /// The program ID will also serve as the owner of the public key, giving
    /// it permission to write data to the account.
    public init(fromPublicKey: PublicKey, seed: String, programId: PublicKey) throws {
        var data = Data()
        data.append(fromPublicKey.data)
        data.append(seed.data(using: .utf8) ?? Data())
        data.append(programId.data)

        let hash = data.sha256()
        self = try PublicKey(hash)
    }

    public var base58: String { Base58.encode(bytes) }

    public var data: Data { Data(bytes) }

}

// MARK: - CustomStringConvertible
extension PublicKey: CustomStringConvertible {

    public var description: String {
        base58
    }
}

// MARK: - Hashable
extension PublicKey: Hashable { }

// MARK: - Equatable
extension PublicKey: Equatable { }

// MARK: - Codable
extension PublicKey: Codable {

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(base58)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        try self.init(string)
    }
}

extension PublicKey: BufferLayoutProperty {

    public init(buffer: Data, pointer: inout Int) throws {
        guard buffer.count > pointer else {
            throw BufferLayoutError.bytesLengthIsNotValid
        }
        bytes = Array(buffer[pointer..<pointer+Self.numberOfBytes])
        pointer += Self.numberOfBytes
    }

    public func serialize() throws -> Data {
        data
    }

}
