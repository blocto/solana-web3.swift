//
//  File.swift
//  
//
//  Created by Scott on 2022/4/1.
//

import Foundation

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
}

/// A subset of Commitment levels, which are at least optimistically confirmed
public enum Finality: String, Encodable {
    /// Query the most recent block which has reached 1 confirmation by the cluster
    case confirmed
    /// Query the most recent block which has been finalized by the cluster
    case finalized
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
    public let extra: Encodable?

    public init?(
        commitment: Commitment? = nil,
        encoding: RpcRequestEncoding? = nil,
        extra: Encodable? = nil
    ) {
        if commitment == nil ||
            encoding == nil ||
            extra == nil {
            return nil
        }
        self.commitment = commitment
        self.encoding = encoding
        self.extra = extra
    }

    public func encode(to encoder: Encoder) throws {
        try commitment?.encode(to: encoder)
        try encoding?.encode(to: encoder)
        try extra?.encode(to: encoder)
    }
}

public enum TokenAccountsFilter {
    case mint(PublicKey)
    case programId(PublicKey)
}
