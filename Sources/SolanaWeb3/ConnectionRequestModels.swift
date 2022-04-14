//
//  File.swift
//  
//
//  Created by Scott on 2022/4/1.
//

import Foundation

public typealias SignatureStatus = String

struct JSONRpcRequest: Encodable {

    let id = UUID().uuidString
    let method: String
    let jsonrpc: String = "2.0"
    let params: [Encodable]

    init(method: String, params: [Encodable]) {
        self.method = method
        self.params = params
    }

    enum CodingKeys: String, CodingKey {
        case id
        case method
        case jsonrpc
        case params
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(method, forKey: .method)
        try container.encode(jsonrpc, forKey: .jsonrpc)
        let wrappedDict = params.map(EncodableWrapper.init(wrapped:))
        try container.encode(wrappedDict, forKey: .params)
    }
}

struct EncodableWrapper: Encodable {
    let wrapped: Encodable

    func encode(to encoder: Encoder) throws {
        try self.wrapped.encode(to: encoder)
    }
}

/// The level of commitment desired when querying state
public enum Commitment: String, Encodable {
    /// Query the most recent block which has reached 1 confirmation by the connected node
    case processed
    /// Query the most recent block which has reached 1 confirmation by the cluster
    case confirmed
    /// Query the most recent block which has been finalized by the cluster
    case finalized

    var toFinality: Finality? {
        switch self {
        case .processed:
            return nil
        case .confirmed:
            return .confirmed
        case .finalized:
            return .finalized
        }
    }
}

/// A subset of Commitment levels, which are at least optimistically confirmed
public enum Finality: String, Encodable {
    /// Query the most recent block which has reached 1 confirmation by the cluster
    case confirmed
    /// Query the most recent block which has been finalized by the cluster
    case finalized

    var toCommitment: Commitment {
        switch self {
        case .confirmed:
            return .confirmed
        case .finalized:
            return .finalized
        }
    }
}

/// Configuration object for changing `getLargestAccounts` query behavior
public enum LargestAccountsFilter: String, Encodable {
    /// the largest accounts that are part of the circulating supply
    case circulating
    /// the largest accounts that are not part of the circulating supply
    case nonCirculating
}

public enum RpcRequestEncoding: String, Codable {
    case jsonParsed
    case base64
}

public struct RpcRequestConfiguration: Encodable {
    public let commitment: Commitment?
    public let encoding: RpcRequestEncoding?
    public let extra: [String: Encodable]?

    public init?(
        commitment: Commitment? = nil,
        encoding: RpcRequestEncoding? = nil,
        extra: [String: Encodable]? = nil
    ) {
        let extra = extra?.isEmpty == true ? nil : extra
        if commitment == nil &&
            encoding == nil &&
            extra == nil {
            return nil
        }
        self.commitment = commitment
        self.encoding = encoding
        self.extra = extra
    }

    public init?(
        finality: Finality?,
        encoding: RpcRequestEncoding? = nil,
        extra: [String: Encodable]? = nil
    ) {
        self.init(
            commitment: finality?.toCommitment,
            encoding: encoding,
            extra: extra)
    }

    private struct CodingKeys: CodingKey {
        var stringValue: String
        var intValue: Int?

        init(stringValue: String) {
           self.stringValue = stringValue
           self.intValue = nil
        }

        init?(intValue: Int) {
           self.stringValue = "\(intValue)"
           self.intValue = intValue
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(commitment, forKey: CodingKeys(stringValue: "commitment"))
        try container.encodeIfPresent(encoding, forKey: CodingKeys(stringValue: "encoding"))
        if let extra = extra {
            for (key, value) in extra {
                let wrapper = EncodableWrapper(wrapped: value)
                try container.encodeIfPresent(wrapper, forKey: CodingKeys(stringValue: key))
            }
        }
    }
}

public enum TokenAccountsFilter {
    case mint(PublicKey)
    case programId(PublicKey)
}

public struct GetSupplyConfig: Encodable {
    /// The level of commitment desired
    public let commitment: Commitment?

    /// Exclude non circulating accounts list from response
    public let excludeNonCirculatingAccountsList: Bool?

    public init(
        commitment: Commitment? = nil,
        excludeNonCirculatingAccountsList: Bool? = nil
    ) {
        self.commitment = commitment
        self.excludeNonCirculatingAccountsList = excludeNonCirculatingAccountsList
    }
}

/// Data slice argument for getProgramAccounts
public struct DataSlice: Encodable {

    /// offset of data slice
    public let offset: UInt64

    /// length of data slice
    public let length: UInt64
}

/// Memory comparison filter for getProgramAccounts
public struct MemcmpFilter: Encodable {

    public let memcmp: Memcmp

    public struct Memcmp: Encodable {
        /// offset into program account data to start comparison
        public let offset: UInt64

        /// data to match, as base-58 encoded string and limited to less than 129 bytes
        public let bytes: String
    }
}

/// Data size comparison filter for getProgramAccounts
public struct DataSizeFilter: Encodable {
    /// Size of data for program account data length comparison
    public let dataSize: UInt64
}

/// A filter object for getProgramAccounts
public enum GetProgramAccountsFilter: Encodable {
    case memcmpFilter(MemcmpFilter)
    case dataSizeFilter(DataSizeFilter)

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .memcmpFilter(memcmpFilter):
            try container.encode(memcmpFilter)
        case let .dataSizeFilter(dataSizeFilter):
            try container.encode(dataSizeFilter)
        }
    }
}

/// Information describing a cluster node
public struct ContactInfo: Decodable {

    /// Identity public key of the node
    public let pubkey: String

    /// Gossip network address for the node
    public let gossip: String?

    /// TPU network address for the node (null if not available)
    public let tpu: String?

    /// JSON RPC network address for the node (null if not available)
    public let rpc: String?

    /// Software version of the node (null if not available)
    public let version: String?
}

/// Information describing a vote account
public struct VoteAccountInfo: Decodable {

    /// Public key of the vote account
    public let votePubkey: String

    /// Identity public key of the node voting with this account
    public let nodePubkey: String

    /// The stake, in lamports, delegated to this vote account and activated
    public let activatedStake: UInt64

    /// Whether the vote account is staked for this epoch
    public let epochVoteAccount: Bool

    /// Recent epoch voting credit history for this voter. [epoch, credits, previousCredits]
    public let epochCredits: [[Int64]]

    /// A percentage (0-100) of rewards payout owed to the voter
    public let commission: UInt64

    /// Most recent slot voted on by this vote account
    public let lastVote: UInt64
}

/// A collection of cluster vote accounts
public struct VoteAccountStatus: Decodable {

    /// Active vote accounts
    public let current: [VoteAccountInfo]

    /// Inactive vote accounts
    public let delinquent: [VoteAccountInfo]
}

/// Configuration object for changing query behavior
public struct SignatureStatusConfig: Encodable {

    /// enable searching status history, not needed for recent transactions
    public let searchTransactionHistory: Bool
}


public struct GetBlockProductionConfig: Encodable {

    /// Commitment level
    public let commitment: Commitment?

    /// Slot range to return block production for. If parameter not provided, defaults to current epoch.
    public let range: Range?

    /// Only return results for this validator identity (base-58 encoded)
    public let identity: String?

    public struct Range: Encodable {

        /// first slot to return block production information for (inclusive)
        public let firstSlot: UInt64

        /// last slot to return block production information for (inclusive). If parameter not provided, defaults to the highest slot
        public let lastSlot: UInt64?
    }
}

/// Options for getConfirmedSignaturesForAddress2
public struct ConfirmedSignaturesForAddress2Options: Encodable {

    /// Start searching backwards from this transaction signature.
    /// If not provided the search starts from the highest max confirmed block.
    public let before: TransactionSignature?

    /// Search until this transaction signature is reached, if found before `limit`.
    public let until: TransactionSignature?

    /// Maximum transaction signatures to return (between 1 and 1,000, default: 1,000).
    public let limit: UInt64?
}

/// Options for getSignaturesForAddress
public struct SignaturesForAddressOptions: Encodable {

    /// Start searching backwards from this transaction signature.
    /// If not provided the search starts from the highest max confirmed block.
    public let before: TransactionSignature?

    /// Search until this transaction signature is reached, if found before `limit`.
    public let until: TransactionSignature?

    /// Maximum transaction signatures to return (between 1 and 1,000, default: 1,000).
    public let limit: UInt64?
}

/// Options for sending transactions
public struct SendOptions: Encodable {

    /// disable transaction verification step
    public let skipPreflight: Bool?

    /// preflight commitment level
    public let preflightCommitment: Commitment?

    /// Maximum number of times for the RPC node to retry sending the transaction to the leader.
    public let maxRetries: UInt64?

    public init(
        skipPreflight: Bool? = nil,
        preflightCommitment: Commitment? = nil,
        maxRetries: UInt64? = nil
    ) {
        self.skipPreflight = skipPreflight
        self.preflightCommitment = preflightCommitment
        self.maxRetries = maxRetries
    }
}
