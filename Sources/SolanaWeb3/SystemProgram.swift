//
//  SystemProgram.swift
//  SolanaWeb3
//
//  Created by Scott on 2022/3/21.
//

import Foundation

public struct SystemProgram {

    /// Public key that identifies the System program
    public static let programId = try! PublicKey("11111111111111111111111111111111")

    /// Generate a transaction instruction that creates a new account
    ///
    /// - Parameters:
    ///  - fromPublicKey: The account that will transfer lamports to the created account
    ///  - newAccountPublicKey: Public key of the created account
    ///  - lamports: Amount of lamports to transfer to the created account
    ///  - space: Amount of space in bytes to allocate to the created account
    ///  - programId: Public key of the program to assign as the owner of the created account
    public static func createAccount(
        fromPublicKey: PublicKey,
        newAccountPublicKey: PublicKey,
        lamports: UInt64,
        space: UInt64,
        programId: PublicKey
    ) throws -> TransactionInstruction {
        let layout = SystemInstructionLayout.Create(
            lamports: lamports,
            space: space,
            programId: programId)

        return TransactionInstruction(
            keys: [
                AccountMeta(publicKey: fromPublicKey, isSigner: true, isWritable: true),
                AccountMeta(publicKey: newAccountPublicKey, isSigner: true, isWritable: true)
            ],
            programId: programId,
            data: try layout.serialize())
    }

    /// Generate a transaction instruction that transfers lamports from one account to another
    ///
    /// - Parameters:
    ///  - fromPublicKey: Account that will transfer lamports
    ///  - toPublicKey: Account that will receive transferred lamports
    ///  - lamports: Amount of lamports to transfer
    public static func transfer(
        fromPublicKey: PublicKey,
        toPublicKey: PublicKey,
        lamports: UInt64
    ) throws -> TransactionInstruction {
//        const type = SYSTEM_INSTRUCTION_LAYOUTS.Transfer;
//              data = encodeData(type, {lamports: params.lamports});
//              keys = [
//                {pubkey: params.fromPubkey, isSigner: true, isWritable: true},
//                {pubkey: params.toPubkey, isSigner: false, isWritable: true},
//              ];
//        return new TransactionInstruction({
//              keys,
//              programId: this.programId,
//              data,
//            });
    }

//    public static func transferInstruction(
//        from fromPublicKey: PublicKey,
//        to toPublicKey: PublicKey,
//        lamports: UInt64
//    ) -> TransactionInstruction {
//
//        TransactionInstruction(
//            keys: [
//                Account.Meta(publicKey: fromPublicKey, isSigner: true, isWritable: true),
//                Account.Meta(publicKey: toPublicKey, isSigner: false, isWritable: true)
//            ],
//            programId: PublicKey.programId,
//            data: [Index.transfer, lamports]
//        )
//    }
//
//    public static func assertOwnerInstruction(
//        destinationAccount: PublicKey
//    ) -> TransactionInstruction {
//        TransactionInstruction(
//            keys: [
//                Account.Meta(publicKey: destinationAccount, isSigner: false, isWritable: false)
//            ],
//            programId: .ownerValidationProgramId,
//            data: [PublicKey.programId]
//        )
//    }
}

public enum SystemInstructionLayout {

    public enum SystemInstructionType: UInt32, BufferLayoutProperty {
        case create = 0
        case assign = 1
        case transfer = 2
        case createWithSeed = 3
        case advanceNonceAccount = 4
        case withdrawNonceAccount = 5
        case initializeNonceAccount = 6
        case authorizeNonceAccount = 7
        case allocate = 8
        case allocateWithSeed = 9
        case assignWithSeed = 10
        case transferWithSeed = 11

        public init(buffer: Data, pointer: inout Int) throws {
            let size = MemoryLayout<Self>.size
            guard buffer.count >= size else {
                throw BufferLayoutError.bytesLengthIsNotValid
            }
            let data = Array(buffer[pointer..<pointer+size])
            if let type = SystemInstructionType(rawValue: data.toUInt(ofType: UInt32.self)) {
                self = type
            } else {
                throw BufferLayoutError.bytesLengthIsNotValid
            }
            pointer += size
        }

        public func serialize() throws -> Data {
            var int = self.rawValue
            return Data(bytes: &int, count: MemoryLayout<Self>.size)
        }
    }

    public struct Create: BufferLayout {
        public let instruction: SystemInstructionType = .create
        public let lamports: UInt64
        public let space: UInt64
        public let programId: PublicKey
    }

    public struct Assign: BufferLayout {
        public let instruction: SystemInstructionType = .assign
        public let programId: PublicKey
    }

    public struct Transfer: BufferLayout {
        public let instruction: SystemInstructionType = .transfer
        public let lamports: UInt64
    }

    public struct CreateWithSeed: BufferLayout {
        public let instruction: SystemInstructionType = .createWithSeed
        public let base: PublicKey
        public let seed: String
        public let lamports: UInt64
        public let space: UInt64
        public let programId: PublicKey
    }

    public struct AdvanceNonceAccount: BufferLayout {
        public let instruction: SystemInstructionType = .advanceNonceAccount
    }

    public struct WithdrawNonceAccount: BufferLayout {
        public let instruction: SystemInstructionType = .withdrawNonceAccount
        public let lamports: UInt64
    }

    public struct InitializeNonceAccount: BufferLayout {
        public let instruction: SystemInstructionType = .initializeNonceAccount
        public let authorized: PublicKey
    }

    public struct AuthorizeNonceAccount: BufferLayout {
        public let instruction: SystemInstructionType = .authorizeNonceAccount
        public let authorized: PublicKey
    }

    public struct Allocate: BufferLayout {
        public let instruction: SystemInstructionType = .allocate
        public let space: UInt64
    }

    public struct AllocateWithSeed: BufferLayout {
        public let instruction: SystemInstructionType = .allocate
        public let base: PublicKey
        public let seed: String
        public let space: UInt64
        public let programId: PublicKey
    }

    public struct AssignWithSeed: BufferLayout {
        public let instruction: SystemInstructionType = .assignWithSeed
        public let base: PublicKey
        public let seed: String
        public let programId: PublicKey
    }

    public struct TransferWithSeed: BufferLayout {
        public let instruction: SystemInstructionType = .transferWithSeed
        public let lamports: UInt64
        public let seed: String
        public let programId: PublicKey
    }
}
