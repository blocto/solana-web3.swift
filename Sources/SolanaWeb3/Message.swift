//
//  Message.swift
//  SolanaWeb3
//
//  Created by Scott on 2022/3/17.
//

import Foundation

/// List of instructions to be processed atomically
public struct Message: Equatable {

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
            let startIndex = data.startIndex + index * PublicKey.numberOfBytes
            let endIndex = startIndex + PublicKey.numberOfBytes
            if endIndex < data.endIndex {
                accountKeys.append(Base58.encode(data[startIndex..<endIndex]))
            } else {
                throw Error.invalidInput
            }
        }

        let startIndex = data.startIndex + accountCount * PublicKey.numberOfBytes
        let endIndex = startIndex + PublicKey.numberOfBytes
        let recentBlockhash: Data
        if endIndex < data.endIndex {
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
            let accounts = data[data.startIndex..<data.startIndex + accountCount]
            data = data[(data.startIndex + accountCount)...]
            let dataLength = Shortvec.decodeLength(data: &data)
            let dataBase58 = Base58.encode(data[data.startIndex..<data.startIndex + dataLength])
            data = data[(data.startIndex + dataLength)...]
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

    public init(
        header: MessageHeader,
        accountKeys: [PublicKey],
        recentBlockhash: Blockhash,
        instructions: [CompiledInstruction]
    ) {
        self.header = header
        self.accountKeys = accountKeys
        self.recentBlockhash = recentBlockhash
        self.instructions = instructions
        self.instructions.forEach { instruction in
            indexToProgramIds[instruction.programIdIndex] = self.accountKeys[Int(instruction.programIdIndex)]
        }
    }

    public init(
        header: MessageHeader,
        accountKeys: [String],
        recentBlockhash: Blockhash,
        instructions: [CompiledInstruction]
    ) throws {
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

        data.append(contentsOf: Shortvec.encodeLength(instructions.count))
        instructions.forEach { instruction in
            let decodedData = Base58.decode(instruction.data)
            data.append(instruction.programIdIndex)
            data.append(Shortvec.encodeLength(instruction.accounts.count))
            data.append(contentsOf: instruction.accounts)
            data.append(Shortvec.encodeLength(decodedData.count))
            data.append(contentsOf: decodedData)
        }

        return data
    }
}

// MARK: - Codable
extension Message: Codable {

    enum CodingKeys: String, CodingKey {
        case header
        case accountKeys
        case recentBlockhash
        case instructions
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(header, forKey: .header)
        try container.encode(accountKeys, forKey: .accountKeys)
        try container.encode(recentBlockhash, forKey: .recentBlockhash)
        try container.encode(instructions, forKey: .instructions)
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.header = try values.decode(MessageHeader.self, forKey: .header)
        self.accountKeys = try values.decode([PublicKey].self, forKey: .accountKeys)
        self.recentBlockhash = try values.decode(Blockhash.self, forKey: .recentBlockhash)
        self.instructions = try values.decode([CompiledInstruction].self, forKey: .instructions)
        self.instructions.forEach { instruction in
            indexToProgramIds[instruction.programIdIndex] = self.accountKeys[Int(instruction.programIdIndex)]
        }
    }
}

// MARK: - Error
public extension Message {

    enum Error: Swift.Error {
        case invalidInput
    }
}

// MARK: -

/// The message header, identifying signed and read-only account
public struct MessageHeader: Equatable, Codable {

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

    public init(
        numRequiredSignatures: UInt8,
        numReadonlySignedAccounts: UInt8,
        numReadonlyUnsignedAccounts: UInt8
    ) {
        self.numRequiredSignatures = numRequiredSignatures
        self.numReadonlySignedAccounts = numReadonlySignedAccounts
        self.numReadonlyUnsignedAccounts = numReadonlyUnsignedAccounts
    }
}

/// An instruction to execute by a program
public struct CompiledInstruction: Equatable, Codable {

    /// Index into the transaction keys array indicating the program account that executes this instruction
    public let programIdIndex: UInt8

    /// Ordered indices into the transaction keys array indicating which accounts to pass to the program
    public let accounts: [UInt8]

    /// The program input data encoded as base 58
    public let data: String

    public init(
        programIdIndex: UInt8,
        accounts: [UInt8],
        data: String
    ) {
        self.programIdIndex = programIdIndex
        self.accounts = accounts
        self.data = data
    }
}
