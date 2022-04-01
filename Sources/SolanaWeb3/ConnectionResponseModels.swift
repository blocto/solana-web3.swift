//
//  ConnectionModels.swift
//  SolanaWeb3
//
//  Created by Scott on 2022/4/1.
//

import Foundation

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
}

/// Extra contextual information for RPC responses
public struct Context: Decodable {
    public let slot: UInt64
}

/// Supply
public struct Supply: Decodable {
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
public struct AccountInfo<T: Decodable>: Decodable {
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
}

public struct KeyAccountInfo<T: Decodable>: Decodable {
    public let publicKey: PublicKey
    public let account: AccountInfo<T>

    public enum CodingKeys: String, CodingKey {
        case publicKey = "pubkey"
        case account
    }
}
