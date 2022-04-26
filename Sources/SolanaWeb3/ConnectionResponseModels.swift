//
//  ConnectionModels.swift
//  SolanaWeb3
//
//  Created by Scott on 2022/4/1.
//

import Foundation

public typealias TransactionError = [String: Any]

public struct Response<T: Decodable>: Decodable {
    public let jsonrpc: String
    public let id: String?
    public let result: T?
    public let error: ResponseError?
}

public struct ResponseError: Decodable {
    public let code: Int?
    public let message: String?
    public let data: ResponseErrorData?
}

public struct ResponseErrorData: Decodable {
    public let logs: [String]
}

/// RPC Response with extra contextual information
public struct RpcResponseAndContext<T: Decodable>: Decodable {
    /// response context
    public let context: Context

    /// response value
    public let value: T

    public init(context: Context, value: T) {
        self.context = context
        self.value = value
    }
}

/// Extra contextual information for RPC responses
public struct Context: Decodable {
    public let slot: UInt64

    public init(slot: UInt64) {
        self.slot = slot
    }
}

/// Supply
public struct Supply: Codable {
    /// Total supply in lamports
    public let total: UInt64

    /// Circulating supply in lamports
    public let circulating: UInt64

    /// Non-circulating supply in lamports
    public let nonCirculating: UInt64

    /// List of non-circulating account addresses
    public let nonCirculatingAccounts: [PublicKey]
}

/// Token amount object which returns a token amount in different formats
/// for various client use cases.
public struct TokenAmount: Codable, Hashable {
    /// Raw amount of tokens as string ignoring decimals
    public let amount: String

    /// Number of decimals configured for token's mint
    public let decimals: UInt8

    /// Token amount as float, accounts for decimals
    public let uiAmount: Float64?

    /// Token amount as string, accounts for decimals
    public let uiAmountString: String?
}

/// Information describing an account
public struct AccountInfo<T: BufferLayoutDeserializable>: Decodable {
    /// `true` if this account's data contains a loaded program
    public let executable: Bool

    /// Identifier of the program that owns the account
    public let owner: PublicKey

    /// Number of lamports assigned to the account
    public let lamports: UInt64

    /// Optional data assigned to the account
    public let data: T

    /// Optional rent epoch info for account
    public let rentEpoch: UInt64?

    enum CodingKeys: String, CodingKey {
        case executable
        case owner
        case lamports
        case data
        case rentEpoch
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.executable = try values.decode(Bool.self, forKey: .executable)
        self.owner = try values.decode(PublicKey.self, forKey: .owner)
        self.lamports = try values.decode(UInt64.self, forKey: .lamports)
        let text = try values.decode([String].self, forKey: .data)
        let data = Data(base64Encoded: text[0]) ?? Data()
        var index = 0
        self.data = try T(buffer: data, pointer: &index)
        self.rentEpoch = try values.decodeIfPresent(UInt64.self, forKey: .rentEpoch)
    }
}

public struct KeyAccountInfoPair<T: BufferLayoutDeserializable>: Decodable {
    public let publicKey: PublicKey
    public let account: AccountInfo<T>

    public enum CodingKeys: String, CodingKey {
        case publicKey = "pubkey"
        case account
    }
}

public struct ParsedAccountData<T: Decodable>: Decodable {
    public let program: String
    public let parsed: T
    public let space: UInt64
}

public struct AccountBalancePair: Codable {
    public let address: PublicKey
    public let lamports: UInt64
}

public struct TokenAccountBalancePair: Codable {
    /// Address of the token account
    public let address: PublicKey

    /// Raw amount of tokens as string ignoring decimals
    public let amount: String

    /// Number of decimals configured for token's mint
    public let decimals: UInt64

    /// Token amount as float, accounts for decimals
    public let uiAmount: UInt64?

    /// Token amount as string, accounts for decimals
    public let uiAmountString: String?
}

/// Stake Activation data
public struct StakeActivationData: Decodable {

    /// the stake account's activation state
    public let state: State

    /// stake active during the epoch
    public let active: UInt64

    /// stake inactive during the epoch
    public let inactive: UInt64

    public enum State: String, Decodable {
        case active
        case inactive
        case activating
        case deactivating
    }
}

/// Network Inflation
/// (see https://docs.solana.com/implemented-proposals/ed_overview)
public struct InflationGovernor: Decodable {

    public let foundation: UInt64

    public let foundationTerm: UInt64

    public let initial: UInt64

    public let taper: UInt64

    public let terminal: UInt64
}

/// The inflation reward for an epoch
public struct InflationReward: Decodable {
    /// epoch for which the reward occurs
    public let epoch: UInt64

    /// the slot in which the rewards are effective
    public let effectiveSlot: UInt64

    /// reward amount in lamports
    public let amount: UInt64

    /// post balance of the account in lamports
    public let postBalance: UInt64
}

/// Information about the current epoch
public struct EpochInfo: Decodable {

    public let epoch: UInt64

    public let slotIndex: UInt64

    public let slotsInEpoch: UInt64

    public let absoluteSlot: UInt64

    public let blockHeight: UInt64?

    public let transactionCount: UInt64?
}

/// Leader schedule
/// (see https://docs.solana.com/terminology#leader-schedule)
public typealias LeaderSchedule = [String: [UInt64]]

/// A performance sample
public struct PerfSample: Decodable {
    /// Slot number of sample
    public let slot: UInt64

    /// Number of transactions in a sample window
    public let numTransactions: UInt64

    /// Number of slots in a sample window
    public let numSlots: UInt64

    /// Sample window in seconds
    public let samplePeriodSecs: UInt64
}

public struct BlockhashLastValidBlockHeightPair: Codable {

    public let blockhash: Blockhash

    public let lastValidBlockHeight: UInt64
}

/// Version info for a node
public struct Version: Decodable {

    public let solanaCore: String

    public let featureSet: UInt64?

    enum CodingKeys: String, CodingKey {
        case solanaCore = "solana-core"
        case featureSet = "feature-set"
    }
}

public struct CompiledInnerInstruction: Codable {
    public let index: UInt64
    public let instructions: [CompiledInstruction]
}

public struct TokenBalance: Codable {
    public let accountIndex: UInt64
    public let mint: String
    public let owner: String?
    public let uiTokenAmount: TokenAmount
}

/// Metadata for a confirmed transaction on the ledger
public struct ConfirmedTransactionMeta: Codable {

    /// The fee charged for processing the transaction
    public let fee: UInt64

    /// An array of cross program invoked instructions
    public let innerInstructions: [CompiledInnerInstruction]?

    /// The balances of the transaction accounts before processing
    public let preBalances: [UInt64]

    /// The balances of the transaction accounts after processing
    public let postBalances: [UInt64]

    /// An array of program log messages emitted during a transaction
    public let logMessages: [String]?

    /// The token balances of the transaction accounts before processing
    public let preTokenBalances: [TokenBalance]?

    /// The token balances of the transaction accounts after processing
    public let postTokenBalances: [TokenBalance]?

    /// The error result of transaction processing
    public let err: TransactionError?

    enum CodingKeys: String, CodingKey {
        case fee
        case innerInstructions
        case preBalances
        case postBalances
        case logMessages
        case preTokenBalances
        case postTokenBalances
        case err
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(fee, forKey: .fee)
        try container.encodeIfPresent(innerInstructions, forKey: .innerInstructions)
        try container.encode(preBalances, forKey: .preBalances)
        try container.encode(postBalances, forKey: .postBalances)
        try container.encodeIfPresent(logMessages, forKey: .logMessages)
        try container.encodeIfPresent(preTokenBalances, forKey: .preTokenBalances)
        try container.encodeIfPresent(postTokenBalances, forKey: .postTokenBalances)
        try container.encodeIfPresent(err, forKey: .err)
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.fee = try values.decode(UInt64.self, forKey: .fee)
        self.innerInstructions = try values.decodeIfPresent([CompiledInnerInstruction].self, forKey: .innerInstructions)
        self.preBalances = try values.decode([UInt64].self, forKey: .preBalances)
        self.postBalances = try values.decode([UInt64].self, forKey: .postBalances)
        self.logMessages = try values.decodeIfPresent([String].self, forKey: .logMessages)
        self.preTokenBalances = try values.decodeIfPresent([TokenBalance].self, forKey: .preTokenBalances)
        self.postTokenBalances = try values.decodeIfPresent([TokenBalance].self, forKey: .postTokenBalances)
        self.err = try values.decodeIfPresent(TransactionError.self, forKey: .err)
    }
}

/// A processed block fetched from the RPC API
public struct BlockResponse: Decodable {

    /// Blockhash of this block
    public let blockhash: Blockhash

    /// Blockhash of this block's parent
    public let previousBlockhash: Blockhash

    /// Slot index of this block's parent
    public let parentSlot: UInt64

    /// Array of transactions with status meta and original message
    public let transactions: [TransactionWithMetaAndMessage]

    /// Vector of block rewards
    public let rewards: [Reward]

    /// The unix timestamp of when the block was processed
    public let blockTime: UInt64?

    public struct TransactionWithMetaAndMessage: Decodable {

        /// The transaction
        public let transaction: Transaction

        /// Metadata produced from the transaction
        public let meta: ConfirmedTransactionMeta?

        public struct Transaction: Decodable {
            /// The transaction message
            public let message: Message

            /// The transaction signatures
            public let signatures: [String]
        }
    }

    public struct Reward: Decodable {

        /// Public key of reward recipient
        public let pubkey: String

        /// Reward value in lamports
        public let lamports: Int64

        /// Account balance after reward is applied
        public let postBalance: UInt64?

        /// Type of reward received
        public let rewardType: String?
    }
}

/// recent block production information
public struct BlockProduction: Codable {

    /// a dictionary of validator identities, as base-58 encoded strings. Value is a two element array containing the number of leader slots and the number of blocks produced
    public let byIdentity: [String: [UInt64]]

    /// Block production slot range
    public let range: Range

    public struct Range: Codable {

        /// first slot of the block production information (inclusive)
        public let firstSlot: UInt64

        /// last slot of block production information (inclusive)
        public let lastSlot: UInt64
    }
}

/// A processed transaction from the RPC API
public struct TransactionResponse: Codable {

    /// The slot during which the transaction was processed
    public let slot: UInt64

    /// The transaction
    public let transaction: Transaction

    /// Metadata produced from the transaction
    public let meta: ConfirmedTransactionMeta?

    /// The unix timestamp of when the transaction was processed
    public let blockTime: UInt64?

    public struct Transaction: Codable {
        /// The transaction message
        public let message: Message

        /// The transaction signatures
        public let signatures: [String]
    }
}

/// A Block on the ledger with signatures only
public struct BlockSignatures: Decodable {

    /// Blockhash of this block
    public let blockhash: Blockhash

    /// Blockhash of this block's parent
    public let previousBlockhash: Blockhash

    /// Slot index of this block's parent
    public let parentSlot: UInt64

    /// Array of signatures
    public let signatures: [String]

    /// The unix timestamp of when the block was processed
    public let blockTime: UInt64?
}

/// A confirmed signature with its status
public struct ConfirmedSignatureInfo: Decodable {

    /// the transaction signature
    public let signature: String

    /// when the transaction was processed
    public let slot: UInt64

    /// error, if any
    public let err: TransactionError?

    /// memo associated with the transaction, if any
    public let memo: String?

    /// The unix timestamp of when the transaction was processed
    public let blockTime: UInt64?

    enum CodingKeys: String, CodingKey {
        case signature
        case slot
        case err
        case memo
        case blockTime
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.signature = try values.decode(String.self, forKey: .signature)
        self.slot = try values.decode(UInt64.self, forKey: .slot)
        self.err = try values.decodeIfPresent(TransactionError.self, forKey: .err)
        self.memo = try values.decodeIfPresent(String.self, forKey: .memo)
        self.blockTime = try values.decodeIfPresent(UInt64.self, forKey: .blockTime)
    }
}

public struct SimulatedTransactionAccountInfo: Codable {

    /// `true` if this account's data contains a loaded program
    public let executable: Bool

    /// Identifier of the program that owns the account
    public let owner: String

    /// Number of lamports assigned to the account
    public let lamports: UInt64

    /// Optional data assigned to the account
    public let data: [String]

    /// Optional rent epoch info for account
    public let rentEpoch: UInt64?
}

public struct SimulatedTransactionResponse: Codable {

    public let err: TransactionError?

    public let logs: [String]?

    public let accounts: [SimulatedTransactionAccountInfo?]?

    public let unitsConsumed: UInt64?

    enum CodingKeys: String, CodingKey {
        case err
        case logs
        case accounts
        case unitsConsumed
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(err, forKey: .err)
        try container.encodeIfPresent(logs, forKey: .logs)
        try container.encodeIfPresent(accounts, forKey: .accounts)
        try container.encodeIfPresent(unitsConsumed, forKey: .unitsConsumed)
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.err = try values.decodeIfPresent([String: Any].self, forKey: .err)
        self.logs = try values.decodeIfPresent([String].self, forKey: .logs)
        self.accounts = try values.decodeIfPresent([SimulatedTransactionAccountInfo].self, forKey: .accounts)
        self.unitsConsumed = try values.decodeIfPresent(UInt64.self, forKey: .unitsConsumed)
    }
}

/// A parsed transaction message account
public struct ParsedMessageAccount: Decodable {

    /// Public key of the account
    public let publicKey: PublicKey

    /// Indicates if the account signed the transaction
    public let signer: Bool

    /// Indicates if the account is writable for this transaction
    public let writable: Bool

    public enum CodingKeys: String, CodingKey {
        case publicKey = "pubkey"
        case signer
        case writable
    }
}

/// A parsed transaction instruction
public struct ParsedInstruction<T: Decodable>: Decodable {

    /// Name of the program for this instruction
    public let program: String

    /// ID of the program for this instruction
    public let programId: PublicKey

    /// Parsed instruction info
    public let parsed: T
}

/// A partially decoded transaction instruction
public struct PartiallyDecodedInstruction: Decodable {

    /// Program id called by this instruction
    public let programId: PublicKey

    /// Public keys of accounts passed to this instruction
    public let accounts: [PublicKey]

    /// Raw base-58 instruction data
    public let data: String
}

/// A parsed transaction message
public struct ParsedMessage<T: Decodable>: Decodable {

    /// Accounts used in the instructions
    public let accountKeys: [ParsedMessageAccount]

    /// The atomically executed instructions for the transaction
    public let instructions: [InstructionType]

    /// Recent blockhash
    public let recentBlockhash: String

    public enum InstructionType: Decodable {
        case parsedInstruction(ParsedInstruction<T>)
        case partiallyDecodedInstruction(PartiallyDecodedInstruction)
    }
}

/// A parsed transaction
public struct ParsedTransaction<T: Decodable>: Decodable {

    /// Signatures for the transaction
    public let signatures: [String]

    /// Message of the transaction
    public let message: ParsedMessage<T>
}

/// A parsed transaction on the ledger with meta
public struct ParsedTransactionWithMeta<T: Decodable>: Decodable {

    /// The slot during which the transaction was processed
    public let slot: UInt64

    /// The details of the transaction
    public let transaction: ParsedTransaction<T>

    /// Metadata produced from the transaction
    public let meta: ParsedTransactionMeta<T>?

    /// The unix timestamp of when the transaction was processed
    public let blockTime: UInt64?
}

public struct ParsedInnerInstruction<T: Decodable>: Decodable {

    public let index: UInt64

    public let instructions: [InstructionType]?

    public enum InstructionType: Decodable {
        case parsedInstruction(ParsedInstruction<T>)
        case partiallyDecodedInstruction(PartiallyDecodedInstruction)
    }
}

/// Metadata for a parsed transaction on the ledger
public struct ParsedTransactionMeta<T: Decodable>: Decodable {

    /// The fee charged for processing the transaction
    public let fee: UInt64

    /// An array of cross program invoked parsed instructions
    public let innerInstructions: [ParsedInnerInstruction<T>]?

    /// The balances of the transaction accounts before processing
    public let preBalances: [UInt64]

    /// The balances of the transaction accounts after processing
    public let postBalances: [UInt64]

    /// An array of program log messages emitted during a transaction
    public let logMessages: [String]?

    /// The token balances of the transaction accounts before processing
    public let preTokenBalances: [TokenBalance]?

    /// The token balances of the transaction accounts after processing
    public let postTokenBalances: [TokenBalance]?

    /// The error result of transaction processing
    public let err: TransactionError?

    enum CodingKeys: String, CodingKey {
        case fee
        case innerInstructions
        case preBalances
        case postBalances
        case logMessages
        case preTokenBalances
        case postTokenBalances
        case err
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.fee = try values.decode(UInt64.self, forKey: .fee)
        self.innerInstructions = try values.decodeIfPresent([ParsedInnerInstruction<T>].self, forKey: .innerInstructions)
        self.preBalances = try values.decode([UInt64].self, forKey: .preBalances)
        self.postBalances = try values.decode([UInt64].self, forKey: .postBalances)
        self.logMessages = try values.decodeIfPresent([String].self, forKey: .logMessages)
        self.preTokenBalances = try values.decodeIfPresent([TokenBalance].self, forKey: .preTokenBalances)
        self.postTokenBalances = try values.decodeIfPresent([TokenBalance].self, forKey: .postTokenBalances)
        self.err = try values.decodeIfPresent(TransactionError.self, forKey: .err)
    }
}

/// Signature result
public struct SignatureResult: Codable {

    public let err: TransactionError?

    enum CodingKeys: String, CodingKey {
        case err
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(err, forKey: .err)
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.err = try values.decodeIfPresent(TransactionError.self, forKey: .err)
    }
}
