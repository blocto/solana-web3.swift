//
//  Connection.swift
//  SolanaWeb3
//
//  Created by Scott on 2022/3/30.
//

import Foundation
import Alamofire

public class Connection {

    let endpointURL: URL
    let commitment: Commitment?
    let session: Session

    public init(
        endpointURL: URL,
        commitment: Commitment? = nil,
        session: Session = .default
    ) {
        self.endpointURL = endpointURL
        self.commitment = commitment
        self.session = session
    }

    public convenience init(
        cluster: Cluster,
        commitment: Commitment? = nil,
        session: Session = .default
    ) {
        self.init(
            endpointURL: cluster.clusterApiURL(),
            commitment: commitment,
            session: session)
    }

    private func sendRpcRequest<T: Decodable>(
        method: String,
        args: [Encodable],
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        let headers: HTTPHeaders = ["Content-Type": "application/json"]
        let jsonRpcRequest = JSONRpcRequest(method: method, params: args)
        session.request(
            endpointURL,
            method: .post,
            parameters: jsonRpcRequest,
            encoder: JSONParameterEncoder(),
            headers: headers)
            .responseData { response in
                switch response.result {
                case let .success(data):
                    do {
                        let decoded = try JSONDecoder().decode(Response<T>.self, from: data)
                        if let result = decoded.result {
                            completion(.success(result))
                        } else if let error = decoded.error {
                            completion(.failure(.invalidResponse(error)))
                        } else {
                            completion(.failure(.unknownResponse))
                        }
                    } catch {
                        completion(.failure(Error.decodingFailed(error)))
                    }

                case let .failure(error):
                    completion(.failure(.networkError(error)))
                }
            }
    }

    /// Fetch the balance for the specified public key, return with context
    public func getBalanceAndContext(
        publicKey: PublicKey,
        commitment: Commitment? = nil,
        completion: @escaping (Result<RpcResponseAndContext<UInt64>, Error>) -> Void
    ) {
        let config = RpcRequestConfiguration(
            commitment: commitment ?? self.commitment)
        sendRpcRequest(
            method: "getBalance",
            args: [publicKey.base58, config],
            completion: completion)
    }

    /// Fetch the balance for the specified public key
    public func getBalance(
        publicKey: PublicKey,
        commitment: Commitment? = nil,
        completion: @escaping (Result<UInt64, Error>) -> Void
    ) {
        getBalanceAndContext(publicKey: publicKey, commitment: commitment) { result in
            completion(result.map { $0.value })
        }
    }

}

public enum Commitment: String, Encodable {
    case processed
    case confirmed
    case finalized
}

// MARK: - Error
public extension Connection {

    enum Error: Swift.Error {
        case networkError(AFError)
        case decodingFailed(Swift.Error)
        case invalidResponse(ResponseError)
        case unknownResponse
    }
}

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

public struct Response<T: Decodable>: Decodable {
    public let jsonrpc: String
    public let id: String?
    public let result: T?
    public let error: ResponseError?
    public let method: String?
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
    // response context
    public let context: Context

    // response value
    public let value: T
}

/// Extra contextual information for RPC responses
public struct Context: Decodable {
    public let slot: UInt64
}

public enum RpcRequestEncoding: String, Codable {
    case jsonParsed
    case base64
}

public struct RpcRequestConfiguration: Encodable {
    public let commitment: Commitment?
    public let encoding: String?
    public let extra: Encodable?

    public init(
        commitment: Commitment? = nil,
        encoding: String? = nil,
        extra: Encodable? = nil
    ) {
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
