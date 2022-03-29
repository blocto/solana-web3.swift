//
//  File.swift
//  
//
//  Created by Scott on 2022/3/28.
//

import Foundation

/// Address of the stake config account which configures the rate
/// of stake warmup and cooldown as well as the slashing penalty.
public let stakeConfigID = try! PublicKey("StakeConfig11111111111111111111111111111111")

public enum StakeProgram {

    /// Public key that identifies the Stake program
    public static let programId = try! PublicKey("Stake11111111111111111111111111111111111111")

    /// Max space of a Stake account
    ///
    /// This is generated from the solana-stake-program StakeState struct as
    /// `std::mem::size_of::<StakeState>()`:
    /// https://docs.rs/solana-stake-program/1.4.4/solana_stake_program/stake_state/enum.StakeState.html
    public static let space: UInt64 = 200

    /// Generate an Initialize instruction to add to a Stake Create transaction
    public static func initialize(
        stakePublicKey: PublicKey,
        authorized: Authorized,
        lockup: Lockup = .default
    ) throws -> TransactionInstruction {
        let layout = StakeInstructionLayout.Initialize(
            authorized: Authorized(
                staker: authorized.staker,
                withdrawer: authorized.withdrawer),
            lockup: Lockup(
                unixTimestamp: lockup.unixTimestamp,
                epoch: lockup.epoch,
                custodian: lockup.custodian))
        return TransactionInstruction(
            keys: [
                AccountMeta(publicKey: stakePublicKey, isSigner: false, isWritable: true),
                AccountMeta(publicKey: Sysvar.rentPublicKey, isSigner: false, isWritable: false)
            ],
            programId: programId,
            data: try layout.serialize())
    }

    /// Generate a Transaction that creates a new Stake account at
    /// an address generated with `from`, a seed, and the Stake programId
    public static func createAccountWithSeed(
        fromPublicKey: PublicKey,
        stakePublicKey: PublicKey,
        basePublicKey: PublicKey,
        seed: String,
        authorized: Authorized,
        lockup: Lockup = .default,
        lamports: UInt64
    ) throws -> Transaction {
        var transaction = Transaction()
        transaction.add(
            try SystemProgram.createAccountWithSeed(
                fromPublicKey: fromPublicKey,
                newAccountPublicKey: stakePublicKey,
                basePublicKey: basePublicKey,
                seed: seed,
                lamports: lamports,
                space: space,
                programId: programId
            ))
        transaction.add(try initialize(
            stakePublicKey: stakePublicKey,
            authorized: authorized,
            lockup: lockup))
        return transaction
    }

    /// Generate a Transaction that creates a new Stake account
    public static func createAccount(
        fromPublicKey: PublicKey,
        stakePublicKey: PublicKey,
        authorized: Authorized,
        lockup: Lockup = .default,
        lamports: UInt64
    ) throws -> Transaction {
        var transaction = Transaction()
        transaction.add(
            try SystemProgram.createAccount(
                fromPublicKey: fromPublicKey,
                newAccountPublicKey: stakePublicKey,
                lamports: lamports,
                space: space,
                programId: programId
            ))
        transaction.add(
            try initialize(
                stakePublicKey: stakePublicKey,
                authorized: authorized,
                lockup: lockup
            ))
        return transaction
    }

    /// Generate a Transaction that delegates Stake tokens to a validator
    /// Vote PublicKey. This transaction can also be used to redelegate Stake
    /// to a new validator Vote PublicKey.
    public static func delegate(
        stakePublicKey: PublicKey,
        authorizedPublicKey: PublicKey,
        votePublicKey: PublicKey
    ) throws -> Transaction {
        let layout = StakeInstructionLayout.Delegate()
        var transaction = Transaction()
        transaction.add(
            keys: [
                AccountMeta(publicKey: stakePublicKey, isSigner: false, isWritable: true),
                AccountMeta(publicKey: votePublicKey, isSigner: false, isWritable: false),
                AccountMeta(publicKey: Sysvar.clockPublicKey, isSigner: false, isWritable: false),
                AccountMeta(publicKey: Sysvar.stakeHistoryPublicKey, isSigner: false, isWritable: false),
                AccountMeta(publicKey: stakeConfigID, isSigner: false, isWritable: false),
                AccountMeta(publicKey: authorizedPublicKey, isSigner: true, isWritable: false)
            ],
            programId: programId,
            data: try layout.serialize())
        return transaction
    }

    /// Generate a Transaction that authorizes a new PublicKey as Staker
    /// or Withdrawer on the Stake account.
    public static func authorize(
        stakePublicKey: PublicKey,
        authorizedPublicKey: PublicKey,
        newAuthorizedPublicKey: PublicKey,
        stakeAuthorizationType: StakeAuthorizationType,
        custodianPublicKey: PublicKey?
    ) throws -> Transaction {
        let layout = StakeInstructionLayout.Authorize(
            newAuthorized: newAuthorizedPublicKey,
            stakeAuthorizationType: stakeAuthorizationType.index)
        var keys = [
            AccountMeta(publicKey: stakePublicKey, isSigner: false, isWritable: true),
            AccountMeta(publicKey: Sysvar.clockPublicKey, isSigner: false, isWritable: true),
            AccountMeta(publicKey: authorizedPublicKey, isSigner: true, isWritable: false)
        ]
        if let custodianPublicKey = custodianPublicKey {
            keys.append(AccountMeta(publicKey: custodianPublicKey, isSigner: false, isWritable: false))
        }
        var transaction = Transaction()
        transaction.add(keys: keys, programId: programId, data: try layout.serialize())
        return transaction
    }

    /// Generate a Transaction that authorizes a new PublicKey as Staker
    /// or Withdrawer on the Stake account.
    public static func authorizeWithSeed(
        stakePublicKey: PublicKey,
        authorityBase: PublicKey,
        authoritySeed: String,
        authorityOwner: PublicKey,
        newAuthorizedPublicKey: PublicKey,
        stakeAuthorizationType: StakeAuthorizationType,
        custodianPubkey: PublicKey?
    ) throws -> Transaction {
        let layout = StakeInstructionLayout.AuthorizeWithSeed(
            newAuthorized: newAuthorizedPublicKey,
            stakeAuthorizationType: stakeAuthorizationType.index,
            authoritySeed: authoritySeed,
            authorityOwner: authorityOwner)
        var keys = [
            AccountMeta(publicKey: stakePublicKey, isSigner: false, isWritable: true),
            AccountMeta(publicKey: authorityBase, isSigner: true, isWritable: false),
            AccountMeta(publicKey: Sysvar.clockPublicKey, isSigner: false, isWritable: false)
        ]
        if let custodianPubkey = custodianPubkey {
            keys.append(AccountMeta(publicKey: custodianPubkey, isSigner: false, isWritable: false))
        }
        var transaction = Transaction()
        transaction.add(keys: keys, programId: programId, data: try layout.serialize())
        return transaction
    }

    private static func splitInstruction(
        stakePublicKey: PublicKey,
        authorizedPublicKey: PublicKey,
        splitStakePublicKey: PublicKey,
        lamports: UInt64
    ) throws -> TransactionInstruction {
        let layout = StakeInstructionLayout.Split(lamports: lamports)

        return TransactionInstruction(
            keys: [
                AccountMeta(publicKey: stakePublicKey, isSigner: false, isWritable: true),
                AccountMeta(publicKey: splitStakePublicKey, isSigner: false, isWritable: true),
                AccountMeta(publicKey: authorizedPublicKey, isSigner: true, isWritable: false)
            ],
            programId: programId,
            data: try layout.serialize())
    }

    public static func split(
        stakePublicKey: PublicKey,
        authorizedPublicKey: PublicKey,
        splitStakePublicKey: PublicKey,
        lamports: UInt64
    ) throws -> Transaction {
        var transaction = Transaction()
        transaction.add(
            try SystemProgram.createAccount(
                fromPublicKey: authorizedPublicKey,
                newAccountPublicKey: splitStakePublicKey,
                lamports: 0,
                space: space,
                programId: programId))
        transaction.add(try splitInstruction(
            stakePublicKey: stakePublicKey,
            authorizedPublicKey: authorizedPublicKey,
            splitStakePublicKey: splitStakePublicKey,
            lamports: lamports))
        return transaction
    }

    /// Generate a Transaction that splits Stake tokens into another account
    /// derived from a base public key and seed
    public static func splitWithSeed(
        stakePublicKey: PublicKey,
        authorizedPublicKey: PublicKey,
        splitStakePublicKey: PublicKey,
        basePublicKey: PublicKey,
        seed: String,
        lamports: UInt64
    ) throws -> Transaction {
        var transaction = Transaction()
        transaction.add(try SystemProgram.allocate(
            accountPublicKey: splitStakePublicKey,
            basePublicKey: basePublicKey,
            seed: seed,
            space: space,
            programId: programId))
        transaction.add(try splitInstruction(
            stakePublicKey: stakePublicKey,
            authorizedPublicKey: authorizedPublicKey,
            splitStakePublicKey: splitStakePublicKey,
            lamports: lamports))
        return transaction
    }

    /// Generate a Transaction that merges Stake accounts.
    public static func merge(
        stakePublicKey: PublicKey,
        sourceStakePublicKey: PublicKey,
        authorizedPublicKey: PublicKey
    ) throws -> Transaction {
        let layout = StakeInstructionLayout.Merge()
        var transaction = Transaction()
        transaction.add(
            keys: [
                AccountMeta(publicKey: stakePublicKey, isSigner: false, isWritable: true),
                AccountMeta(publicKey: sourceStakePublicKey, isSigner: false, isWritable: true),
                AccountMeta(publicKey: Sysvar.clockPublicKey, isSigner: false, isWritable: false),
                AccountMeta(publicKey: Sysvar.stakeHistoryPublicKey, isSigner: false, isWritable: false),
                AccountMeta(publicKey: authorizedPublicKey, isSigner: true, isWritable: false)
            ],
            programId: programId,
            data: try layout.serialize())
        return transaction
    }

    /// Generate a Transaction that withdraws deactivated Stake tokens.
    public static func withdraw(
        stakePublicKey: PublicKey,
        authorizedPublicKey: PublicKey,
        toPublicKey: PublicKey,
        lamports: UInt64,
        custodianPublicKey: PublicKey?
    ) throws -> Transaction {
        let layout = StakeInstructionLayout.Withdraw(lamports: lamports)
        var keys = [
            AccountMeta(publicKey: stakePublicKey, isSigner: false, isWritable: true),
            AccountMeta(publicKey: toPublicKey, isSigner: false, isWritable: true),
            AccountMeta(publicKey: Sysvar.clockPublicKey, isSigner: false, isWritable: false),
            AccountMeta(publicKey: Sysvar.stakeHistoryPublicKey, isSigner: false, isWritable: false),
            AccountMeta(publicKey: authorizedPublicKey, isSigner: true, isWritable: false)
        ]
        if let custodianPublicKey = custodianPublicKey {
            keys.append(AccountMeta(publicKey: custodianPublicKey, isSigner: false, isWritable: false))
        }
        var transaction = Transaction()
        transaction.add(keys: keys, programId: programId, data: try layout.serialize())
        return transaction
    }

    /// Generate a Transaction that deactivates Stake tokens.
    public static func deactivate(
        stakePublicKey: PublicKey,
        authorizedPublicKey: PublicKey
    ) throws -> Transaction {
        let layout = StakeInstructionLayout.Deactivate()
        var transaction = Transaction()
        transaction.add(
            keys: [
                AccountMeta(publicKey: stakePublicKey, isSigner: false, isWritable: true),
                AccountMeta(publicKey: Sysvar.clockPublicKey, isSigner: false, isWritable: false),
                AccountMeta(publicKey: authorizedPublicKey, isSigner: true, isWritable: false)
            ],
            programId: programId,
            data: try layout.serialize())
        return transaction
    }
}

/// Stake account authority info
public struct Authorized: BufferLayout {
    /// stake authority
    public let staker: PublicKey

    /// withdraw authority
    public let withdrawer: PublicKey
}

/// Stake account lockup info
public struct Lockup: BufferLayout {

    public static let `default` = Lockup(unixTimestamp: 0, epoch: 0, custodian: .default)

    /// Unix timestamp of lockup expiration
    public let unixTimestamp: UInt64

    /// Epoch of lockup expiration
    public let epoch: UInt64

    /// Lockup custodian authority
    public let custodian: PublicKey
}

/// Stake authorization type
public struct StakeAuthorizationType: BufferLayout {
    public let index: UInt32
}

public enum StakeInstructionLayout {

    public enum StakeInstructionType: UInt32, BufferLayoutProperty {
        case initialize = 0
        case authorize = 1
        case delegate = 2
        case split = 3
        case withdraw = 4
        case deactivate = 5
        case merge = 7
        case authorizeWithSeed = 8

        public init(buffer: Data, pointer: inout Int) throws {
            let size = MemoryLayout<UInt32>.size
            guard buffer.count >= size else {
                throw BufferLayoutError.bytesLengthIsNotValid
            }
            let data = Array(buffer[pointer..<pointer+size])
            if let type = StakeInstructionType(rawValue: data.toUInt(ofType: UInt32.self)) {
                self = type
            } else {
                throw BufferLayoutError.bytesLengthIsNotValid
            }
            pointer += size
        }

        public func serialize() throws -> Data {
            var int = rawValue
            return Data(bytes: &int, count: MemoryLayout<UInt32>.size)
        }
    }

    public struct Initialize: BufferLayout {
        public let instruction: StakeInstructionType = .initialize
        public let authorized: Authorized
        public let lockup: Lockup
    }

    public struct Authorize: BufferLayout {
        public let instruction: StakeInstructionType = .authorize
        public let newAuthorized: PublicKey
        public let stakeAuthorizationType: UInt32
    }

    public struct Delegate: BufferLayout {
        public let instruction: StakeInstructionType = .delegate
    }

    public struct Split: BufferLayout {
        public let instruction: StakeInstructionType = .split
        public let lamports: UInt64
    }

    public struct Withdraw: BufferLayout {
        public let instruction: StakeInstructionType = .withdraw
        public let lamports: UInt64
    }

    public struct Deactivate: BufferLayout {
        public let instruction: StakeInstructionType = .deactivate
    }

    public struct Merge: BufferLayout {
        public let instruction: StakeInstructionType = .merge
    }

    public struct AuthorizeWithSeed: BufferLayout {
        public let instruction: StakeInstructionType = .authorizeWithSeed
        public let newAuthorized: PublicKey
        public let stakeAuthorizationType: UInt32
        public let authoritySeed: String
        public let authorityOwner: PublicKey
    }
}
