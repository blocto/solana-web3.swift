//
//  Message.swift
//  SolanaWeb3
//
//  Created by Scott on 2022/3/17.
//

import Foundation

/// List of instructions to be processed atomically
public struct Message {

    public let header: MessageHeader
    public let accountKeys: [PublicKey]
    public let recentBlockhash: Blockhash
    public let instructions: [CompiledInstruction]

    private var indexToProgramIds: [UInt8: PublicKey] = [:]

    /// Decode a compiled message into a Message object.
    public init(data: Data) throws {
        var data = data

        guard let numRequiredSignatures = data.popFirst() else {
            throw Error.invalidInput
        }
        guard let numReadonlySignedAccounts = data.popFirst() else {
            throw Error.invalidInput
        }
        guard let numReadonlyUnsignedAccounts = data.popFirst() else {
            throw Error.invalidInput
        }

        let accountCount = Shortvec.decodeLength(data: &data)
        var accountKeys = [String]()
        for index in 0..<accountCount {
            let startIndex = index * PublicKey.numberOfBytes
            let endIndex = startIndex + PublicKey.numberOfBytes
            if endIndex < data.count {
                accountKeys.append(Base58.encode(data[startIndex..<endIndex]))
            } else {
                throw Error.invalidInput
            }
        }

        let startIndex = accountCount * PublicKey.numberOfBytes
        let endIndex = startIndex + PublicKey.numberOfBytes
        let recentBlockhash: Data
        if endIndex < data.count {
            recentBlockhash = data[startIndex..<endIndex]
        } else {
            throw Error.invalidInput
        }

        data = data[endIndex...]
        let instructionCount = Shortvec.decodeLength(data: &data)
        var instructions = [CompiledInstruction]()
        for _ in 0..<instructionCount {
            guard let programIdIndex = data.popFirst() else {
                throw Error.invalidInput
            }

            let accountCount = Shortvec.decodeLength(data: &data)
            let accounts = data[0..<accountCount]
            data = data[accountCount...]
            let dataLength = Shortvec.decodeLength(data: &data)
            let dataBase58 = Base58.encode(data[0..<dataLength])
            data = data[dataLength...]
            instructions.append(CompiledInstruction(
                programIdIndex: programIdIndex,
                accounts: [UInt8](accounts),
                data: dataBase58))
        }

        try self.init(
            header: MessageHeader(
                numRequiredSignatures: numRequiredSignatures,
                numReadonlySignedAccounts: numReadonlySignedAccounts,
                numReadonlyUnsignedAccounts: numReadonlyUnsignedAccounts),
            accountKeys: accountKeys,
            recentBlockhash: Base58.encode(recentBlockhash),
            instructions: instructions)
    }

    public init(header: MessageHeader,
         accountKeys: [PublicKey],
         recentBlockhash: Blockhash,
         instructions: [CompiledInstruction]) {
        self.header = header
        self.accountKeys = accountKeys
        self.recentBlockhash = recentBlockhash
        self.instructions = instructions
        self.instructions.forEach { instruction in
            indexToProgramIds[instruction.programIdIndex] = self.accountKeys[Int(instruction.programIdIndex)]
        }
    }

    public init(header: MessageHeader,
         accountKeys: [String],
         recentBlockhash: Blockhash,
         instructions: [CompiledInstruction]) throws {
        let accountKeys = try accountKeys.map { try PublicKey($0) }
        self.init(header: header, accountKeys: accountKeys, recentBlockhash: recentBlockhash, instructions: instructions)
    }

    public func isAccountSigner(index: Int) -> Bool {
        index < header.numRequiredSignatures
    }

    public func isAccountWritable(index: Int) -> Bool {
        index < header.numRequiredSignatures - header.numReadonlySignedAccounts ||
            (index >= header.numRequiredSignatures &&
             index < accountKeys.count - Int(header.numReadonlyUnsignedAccounts))
    }

    public func isProgramId(index: UInt8) -> Bool {
        indexToProgramIds.keys.contains(index)
    }

    public var programIds: [PublicKey] {
        [PublicKey](indexToProgramIds.values)
    }

    public var nonProgramIds: [PublicKey] {
        let values = indexToProgramIds.values
        return accountKeys.filter { !values.contains($0) }
    }

    public func serialize() -> Data {
        let numKeys = accountKeys.count

        var data = Data()
        data.append(contentsOf: [
            header.numRequiredSignatures,
            header.numReadonlySignedAccounts,
            header.numReadonlyUnsignedAccounts
        ])
        data.append(Shortvec.encodeLength(numKeys))
        accountKeys.forEach { data.append($0.data) }
        data.append(contentsOf: Base58.decode(recentBlockhash))

        instructions.forEach { instruction in
            data.append(instruction.programIdIndex)
            data.append(Shortvec.encodeLength(instruction.accounts.count))
            data.append(contentsOf: instruction.accounts)
            data.append(Shortvec.encodeLength(instruction.data.count))
            data.append(contentsOf: Base58.decode(instruction.data))
        }

        return data
    }
}

// MARK: - Error
public extension Message {

    public enum Error: Swift.Error {
        case invalidInput
    }
}

/// The message header, identifying signed and read-only account
public struct MessageHeader: Decodable {

    /// The number of signatures required for this message to be considered valid. The
    /// signatures must match the first `numRequiredSignatures` of `accountKeys`.
    public let numRequiredSignatures: UInt8

    /// The last `numReadonlySignedAccounts` of the signed keys are read-only accounts
    public let numReadonlySignedAccounts: UInt8

    /// The last `numReadonlySignedAccounts` of the unsigned keys are read-only accounts
    public let numReadonlyUnsignedAccounts: UInt8

    public var bytes: [UInt8] {
        [numRequiredSignatures, numReadonlySignedAccounts, numReadonlyUnsignedAccounts]
    }
}

/// An instruction to execute by a program
public struct CompiledInstruction {

    /// Index into the transaction keys array indicating the program account that executes this instruction
    public let programIdIndex: UInt8

    /// Ordered indices into the transaction keys array indicating which accounts to pass to the program
    public let accounts: [UInt8]

    /// The program input data encoded as base 58
    public let data: String
}
