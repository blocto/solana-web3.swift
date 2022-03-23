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
            programId: self.programId,
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
        let layout = SystemInstructionLayout.Transfer(lamports: lamports)
        return TransactionInstruction(
            keys: [
                AccountMeta(publicKey: fromPublicKey, isSigner: true, isWritable: true),
                AccountMeta(publicKey: toPublicKey, isSigner: false, isWritable: true)
            ],
            programId: programId,
            data: try layout.serialize())
    }

    /// Generate a transaction instruction that transfers lamports from one account to another
    ///
    /// - Parameters:
    ///  - fromPublicKey: Account that will transfer lamports
    ///  - basePublicKey: Base public key to use to derive the funding account address
    ///  - toPublicKey: Account that will receive transferred lamports
    ///  - lamports: Amount of lamports to transfer
    ///  - seed: Seed to use to derive the funding account address
    ///  - programId: Program id to use to derive the funding account address
    public static func transfer(
        fromPublicKey: PublicKey,
        basePublicKey: PublicKey,
        toPublicKey: PublicKey,
        lamports: UInt64,
        seed: String,
        programId: PublicKey
    ) throws -> TransactionInstruction {
        let layout = SystemInstructionLayout.TransferWithSeed(
            lamports: lamports,
            seed: seed,
            programId: programId)
        return TransactionInstruction(
            keys: [
                AccountMeta(publicKey: fromPublicKey, isSigner: false, isWritable: true),
                AccountMeta(publicKey: basePublicKey, isSigner: true, isWritable: false),
                AccountMeta(publicKey: toPublicKey, isSigner: false, isWritable: true)
            ],
            programId: self.programId,
            data: try layout.serialize())
    }

    /// Generate a transaction instruction that assigns an account to a program
    ///
    /// - Parameters:
    ///  - accountPublicKey: Public key of the account which will be assigned a new owner
    ///  - programId: Public key of the program to assign as the owner
    public static func assign(
        accountPublicKey: PublicKey,
        programId: PublicKey
    ) throws -> TransactionInstruction {
        let layout = SystemInstructionLayout.Assign(programId: programId)

        return TransactionInstruction(
            keys: [
                AccountMeta(publicKey: accountPublicKey, isSigner: true, isWritable: true),
            ],
            programId: self.programId,
            data: try layout.serialize())
    }

    /// Generate a transaction instruction that assigns an account to a program
    ///
    /// - Parameters:
    ///  - accountPublicKey: Public key of the account which will be assigned a new owner
    ///  - basePublicKey: Base public key to use to derive the address of the assigned account
    ///  - seed: Seed to use to derive the address of the assigned account
    ///  - programId: Public key of the program to assign as the owner
    public static func assign(
        accountPublicKey: PublicKey,
        basePublicKey: PublicKey,
        seed: String,
        programId: PublicKey
    ) throws -> TransactionInstruction {
        let layout = SystemInstructionLayout.AssignWithSeed(
            base: basePublicKey,
            seed: seed,
            programId: programId)

        return TransactionInstruction(
            keys: [
                AccountMeta(publicKey: accountPublicKey, isSigner: false, isWritable: true),
                AccountMeta(publicKey: basePublicKey, isSigner: true, isWritable: false),
            ],
            programId: self.programId,
            data: try layout.serialize())
    }

    /// Generate a transaction instruction that creates a new account at
    /// an address generated with `from`, a seed, and programId
    ///
    /// - Parameters:
    ///  - fromPublicKey: The account that will transfer lamports to the created account
    ///  - newAccountPublicKey: Public key of the created account. Must be pre-calculated with PublicKey.createWithSeed()
    ///  - basePublicKey: Base public key to use to derive the address of the created account.
    ///                   Must be the same as the base key used to create `newAccountPubkey`
    ///  - seed: Seed to use to derive the address of the created account. Must be the same as the seed used to create `newAccountPubkey`
    ///  - lamports: Amount of lamports to transfer to the created account
    ///  - space: Amount of space in bytes to allocate to the created account
    ///  - programId: Public key of the program to assign as the owner of the created account
    public static func createAccountWithSeed(
        fromPublicKey: PublicKey,
        newAccountPublicKey: PublicKey,
        basePublicKey: PublicKey,
        seed: String,
        lamports: UInt64,
        space: UInt64,
        programId: PublicKey
    ) throws -> TransactionInstruction {
        let layout = SystemInstructionLayout.CreateWithSeed(
            base: basePublicKey,
            seed: seed,
            lamports: lamports,
            space: space,
            programId: programId)

        var keys = [
            AccountMeta(publicKey: fromPublicKey, isSigner: true, isWritable: true),
            AccountMeta(publicKey: newAccountPublicKey, isSigner: false, isWritable: true)]
        if basePublicKey != fromPublicKey {
            keys.append(AccountMeta(publicKey: basePublicKey, isSigner: true, isWritable: false))
        }

        return TransactionInstruction(
            keys: keys,
            programId: self.programId,
            data: try layout.serialize())
    }

    /// Generate a transaction that creates a new Nonce account
    ///
    /// - Parameters:
    ///  - fromPublicKey: The account that will transfer lamports to the created nonce account
    ///  - noncePublicKey: Public key of the created nonce account
    ///  - authorizedPublicKey: Public key to set as authority of the created nonce account
    ///  - lamports: Amount of lamports to transfer to the created nonce account
    public static func createNonceAccount(
        fromPublicKey: PublicKey,
        noncePublicKey: PublicKey,
        authorizedPublicKey: PublicKey,
        lamports: UInt64
    ) throws -> Transaction {
        var transaction = Transaction()
        transaction.add(try SystemProgram.createAccount(
            fromPublicKey: fromPublicKey,
            newAccountPublicKey: noncePublicKey,
            lamports: lamports,
            space: try NonceAccountLayout.span,
            programId: programId))
        transaction.add(try nonceInitialize(
            noncePublicKey: noncePublicKey,
            authorizedPublicKey: authorizedPublicKey));

        return transaction
    }

    /// Generate a transaction that creates a new Nonce account
    ///
    /// - Parameters:
    ///  - fromPublicKey: The account that will transfer lamports to the created nonce account
    ///  - noncePubkey: Public key of the created nonce account
    ///  - authorizedPubkey: Public key to set as authority of the created nonce account
    ///  - lamports: Amount of lamports to transfer to the created nonce account
    ///  - basePublicKey: Base public key to use to derive the address of the nonce account
    ///  - seed: Seed to use to derive the address of the nonce account
    public static func createNonceAccount(
        fromPublicKey: PublicKey,
        noncePublicKey: PublicKey,
        authorizedPublicKey: PublicKey,
        lamports: UInt64,
        basePublicKey: PublicKey,
        seed: String
    ) throws -> Transaction {
        var transaction = Transaction()
        transaction.add(try SystemProgram.createAccountWithSeed(
            fromPublicKey: fromPublicKey,
            newAccountPublicKey: noncePublicKey,
            basePublicKey: basePublicKey,
            seed: seed,
            lamports: lamports,
            space: try NonceAccountLayout.span,
            programId: programId)
        )

        transaction.add(try nonceInitialize(
            noncePublicKey: noncePublicKey,
            authorizedPublicKey: authorizedPublicKey));
        return transaction
    }

    /// Generate an instruction to initialize a Nonce account
    ///
    /// - Parameters:
    ///  - noncePublicKey: Nonce account which will be initialized
    ///  - authorizedPublicKey: Public key to set as authority of the initialized nonce account
    public static func nonceInitialize(
        noncePublicKey: PublicKey,
        authorizedPublicKey: PublicKey
    ) throws -> TransactionInstruction {
        let layout = SystemInstructionLayout.InitializeNonceAccount(authorized: authorizedPublicKey)
        return TransactionInstruction(
            keys: [
                AccountMeta(publicKey: noncePublicKey, isSigner: false, isWritable: true),
                AccountMeta(publicKey: Sysvar.recentBlockhashesPublicKey, isSigner: false, isWritable: false),
                AccountMeta(publicKey: Sysvar.rentPublicKey, isSigner: false, isWritable: false)
            ],
            programId: programId,
            data: try layout.serialize())
    }

    /// Generate an instruction to advance the nonce in a Nonce account
    ///
    /// - Parameters:
    ///  - noncePublicKey: Nonce account
    ///  - authorizedPublicKey: Public key of the nonce authority
    public static func nonceAdvance(
        noncePublicKey: PublicKey,
        authorizedPublicKey: PublicKey
    ) throws -> TransactionInstruction {
        let layout = SystemInstructionLayout.AdvanceNonceAccount()
        return TransactionInstruction(
            keys: [
                AccountMeta(publicKey: noncePublicKey, isSigner: false, isWritable: true),
                AccountMeta(publicKey: Sysvar.recentBlockhashesPublicKey, isSigner: false, isWritable: false),
                AccountMeta(publicKey: authorizedPublicKey, isSigner: true, isWritable: false)
            ],
            programId: programId,
            data: try layout.serialize())
    }

    /// Generate a transaction instruction that withdraws lamports from a Nonce account
    ///
    /// - Parameters:
    ///  - noncePublicKey: Nonce account
    ///  - authorizedPublicKey: Public key of the nonce authority
    ///  - toPublicKey: Public key of the account which will receive the withdrawn nonce account balance
    ///  - lamports: Amount of lamports to withdraw from the nonce account
    public static func nonceWithdraw(
        noncePublicKey: PublicKey,
        authorizedPublicKey: PublicKey,
        toPublicKey: PublicKey,
        lamports: UInt64
    ) throws -> TransactionInstruction {
        let layout = SystemInstructionLayout.WithdrawNonceAccount(lamports: lamports)

        return TransactionInstruction(
            keys: [
                AccountMeta(publicKey: noncePublicKey, isSigner: false, isWritable: true),
                AccountMeta(publicKey: toPublicKey, isSigner: false, isWritable: true),
                AccountMeta(publicKey: Sysvar.recentBlockhashesPublicKey, isSigner: false, isWritable: false),
                AccountMeta(publicKey: Sysvar.rentPublicKey, isSigner: false, isWritable: false),
                AccountMeta(publicKey: authorizedPublicKey, isSigner: true, isWritable: false)
            ],
            programId: programId,
            data: try layout.serialize())
    }

    /// Generate a transaction instruction that authorizes a new PublicKey as the authority
    /// on a Nonce account.
    ///
    /// - Parameters:
    ///  - noncePublicKey: Nonce account
    ///  - authorizedPublicKey: Public key of the current nonce authority
    ///  - newAuthorizedPublicKey: Public key to set as the new nonce authority
    public static func nonceAuthorize(
        noncePublicKey: PublicKey,
        authorizedPublicKey: PublicKey,
        newAuthorizedPublicKey: PublicKey
    ) throws -> TransactionInstruction {
        let layout = SystemInstructionLayout.AuthorizeNonceAccount(authorized: newAuthorizedPublicKey)

        return TransactionInstruction(
            keys: [
                AccountMeta(publicKey: noncePublicKey, isSigner: false, isWritable: true),
                AccountMeta(publicKey: authorizedPublicKey, isSigner: true, isWritable: false)
            ],
            programId: programId,
            data: try layout.serialize())
    }

    /// Generate a transaction instruction that allocates space in an account without funding
    ///
    /// - Parameters:
    ///  - accountPublicKey: Account to allocate
    ///  - space: Amount of space in bytes to allocate
    public static func allocate(
        accountPublicKey: PublicKey,
        space: UInt64
    ) throws -> TransactionInstruction {
        let layout = SystemInstructionLayout.Allocate(space: space)
        return TransactionInstruction(
            keys: [
                AccountMeta(publicKey: accountPublicKey, isSigner: true, isWritable: true)
            ],
            programId: programId,
            data: try layout.serialize())
    }

    /// Generate a transaction instruction that allocates space in an account without funding
    /// - Parameters:
    ///  - accountPublicKey: Account to allocate
    ///  - basePublicKey: Base public key to use to derive the address of the allocated account
    ///  - seed: Seed to use to derive the address of the allocated account
    ///  - space: Amount of space in bytes to allocate
    ///  - programId: Public key of the program to assign as the owner of the allocated account
    public static func allocate(
        accountPublicKey: PublicKey,
        basePublicKey: PublicKey,
        seed: String,
        space: UInt64,
        programId: PublicKey
    ) throws -> TransactionInstruction {
        let layout = SystemInstructionLayout.AllocateWithSeed(
            base: basePublicKey,
            seed: seed,
            space: space,
            programId: programId)

        return TransactionInstruction(
            keys: [
                AccountMeta(publicKey: accountPublicKey, isSigner: false, isWritable: true),
                AccountMeta(publicKey: basePublicKey, isSigner: true, isWritable: false)
            ],
            programId: self.programId,
            data: try layout.serialize())
    }
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

public struct NonceAccountLayout: BufferLayout {
    public let version: UInt32
    public let state: UInt32
    public let authorizedPublicKey: PublicKey
    public let nonce: PublicKey
    public let feeCalculator: [FeeCalculator]
}
