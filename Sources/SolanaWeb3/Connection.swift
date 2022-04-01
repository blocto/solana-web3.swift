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

    private func sendRpcRequest(
        method: String,
        args: [Encodable],
        completion: @escaping (Result<Data, Error>) -> Void
    ) {
        let headers: HTTPHeaders = ["Content-Type": "application/json"]
        let jsonRpcRequest = JSONRpcRequest(method: method, params: args)
        let request = session.request(
            endpointURL,
            method: .post,
            parameters: jsonRpcRequest,
            encoder: JSONParameterEncoder(),
            headers: headers)
        request.responseData { response in
            switch response.result {
            case let .success(data):
//                debugPrint(String(data: data, encoding: .utf8) ?? "empty")
                completion(.success(data))
            case let .failure(error):
                completion(.failure(.networkError(error)))
            }
        }
//        request.cURLDescription { info in
//            debugPrint(info)
//        }
    }

    private func sendRpcRequest<T: Decodable>(
        method: String,
        args: [Encodable],
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        sendRpcRequest(method: method, args: args) { result in
            completion(result.flatMap { data -> Result<T, Error> in
                do {
                    let decoded = try JSONDecoder().decode(Response<T>.self, from: data)
                    if let result = decoded.result {
                        return .success(result)
                    } else if let error = decoded.error {
                        return .failure(.invalidResponse(error))
                    } else {
                        return .failure(.unknownResponse)
                    }
                } catch {
                    return .failure(Error.decodingFailed(error))
                }
            })
        }
    }

    private func sendRpcRequest<T: Decodable>(
        method: String,
        args: [Encodable],
        completion: @escaping (Result<T?, Error>) -> Void
    ) {
        sendRpcRequest(method: method, args: args) { result in
            completion(result.flatMap { data -> Result<T?, Error> in
                do {
                    let decoded = try JSONDecoder().decode(Response<T>.self, from: data)
                    if let error = decoded.error {
                        return .failure(.invalidResponse(error))
                    } else {
                        return .success(decoded.result)
                    }
                } catch {
                    return .failure(Error.decodingFailed(error))
                }
            })
        }
    }

    /// Fetch the balance for the specified public key, return with context
    public func getBalanceAndContext(
        publicKey: PublicKey,
        commitment: Commitment? = nil,
        completion: @escaping (Result<RpcResponseAndContext<UInt64>, Error>) -> Void
    ) {
        var args: [Encodable] = [publicKey.base58]
        if let config = RpcRequestConfiguration(commitment: commitment ?? self.commitment) {
            args.append(config)
        }
        sendRpcRequest(
            method: "getBalance",
            args: args,
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

    /// Fetch the estimated production time of a block
    public func getBlockTime(
        slot: UInt64,
        completion: @escaping (Result<UInt64?, Error>) -> Void
    ) {
        sendRpcRequest(
            method: "getBlockTime",
            args: [slot],
            completion: completion)
    }

    /// Fetch the lowest slot that the node has information about in its ledger.
    /// This value may increase over time if the node is configured to purge older ledger data
    public func getMinimumLedgerSlot(completion: @escaping (Result<UInt64, Error>) -> Void) {
        sendRpcRequest(
            method: "minimumLedgerSlot",
            args: [],
            completion: completion)
    }

    /// Fetch the slot of the lowest confirmed block that has not been purged from the ledger
    public func getFirstAvailableBlock(completion: @escaping (Result<UInt64, Error>) -> Void) {
        sendRpcRequest(
            method: "getFirstAvailableBlock",
            args: [],
            completion: completion)
    }

    /// Fetch information about the current supply
    /// - Parameters:
    ///  - commitment: The level of commitment desired
    ///  - excludeNonCirculatingAccountsList: Exclude non circulating accounts list from response
    public func getSupply(
        commitment: Commitment? = nil,
        excludeNonCirculatingAccountsList: Bool? = nil,
        completion: @escaping (Result<RpcResponseAndContext<Supply>, Error>) -> Void
    ) {
        let config = RpcRequestConfiguration(
            commitment: commitment ?? self.commitment,
            extra: excludeNonCirculatingAccountsList.flatMap { ["excludeNonCirculatingAccountsList": $0] })
        var args: [Encodable] = []
        if let config = config {
            args.append(config)
        }
        sendRpcRequest(
            method: "getSupply",
            args: args,
            completion: completion)
    }

    /// Fetch the current supply of a token mint
    public func getTokenSupply(
        tokenMintAddress: PublicKey,
        commitment: Commitment? = nil,
        completion: @escaping (Result<RpcResponseAndContext<TokenAmount>, Error>) -> Void
    ) {
        var args: [Encodable] = [tokenMintAddress.base58]
        if let config = RpcRequestConfiguration(commitment: commitment ?? self.commitment) {
            args.append(config)
        }
        sendRpcRequest(
            method: "getTokenSupply",
            args: args,
            completion: completion)
    }

    /// Fetch the current balance of a token account
    public func getTokenAccountBalance(
        tokenAddress: PublicKey,
        commitment: Commitment? = nil,
        completion: @escaping (Result<RpcResponseAndContext<TokenAmount>, Error>) -> Void
    ) {
        var args: [Encodable] = [tokenAddress.base58]
        if let config = RpcRequestConfiguration(commitment: commitment ?? self.commitment) {
            args.append(config)
        }
        sendRpcRequest(
            method: "getTokenAccountBalance",
            args: args,
            completion: completion)
    }

    /// Fetch all the token accounts owned by the specified account
    public func getTokenAccountsByOwner(
        ownerAddress: PublicKey,
        filter: TokenAccountsFilter,
        commitment: Commitment? = nil,
        completion: @escaping (Result<RpcResponseAndContext<KeyAccountInfo<Data>>, Error>) -> Void
    ) {
        var args: [Encodable] = [ownerAddress.base58]
        switch filter {
        case .mint(let publicKey):
            args.append(["mint": publicKey.base58])
        case .programId(let publicKey):
            args.append(["programId": publicKey.base58])
        }
        if let config = RpcRequestConfiguration(commitment: commitment ?? self.commitment, encoding: .base64) {
            args.append(config)
        }
        sendRpcRequest(
            method: "getTokenAccountsByOwner",
            args: args,
            completion: completion)
    }

    /// Fetch parsed token accounts owned by the specified account
    // TODO: public func getParsedTokenAccountsByOwner

    /// Fetch the 20 largest accounts with their current balances
    // TODO: public func getLargestAccounts

    /// Fetch the 20 largest token accounts with their current balances
    /// for a given mint.
    // TODO: public func getTokenLargestAccounts

    /// Fetch all the account info for the specified public key, return with context
    public func getAccountInfoAndContext(
        publicKey: PublicKey,
        commitment: Commitment? = nil,
        completion: @escaping (Result<RpcResponseAndContext<AccountInfo<Data>>, Error>) -> Void
    ) {
        var args: [Encodable] = [publicKey.base58]
        if let config = RpcRequestConfiguration(commitment: commitment ?? self.commitment, encoding: .base64) {
            args.append(config)
        }
        sendRpcRequest(
            method: "getAccountInfo",
            args: args,
            completion: completion)
    }

    /// Fetch parsed account info for the specified public key
    // TODO: public func getParsedAccountInfo


    /// Fetch all the account info for the specified public key
    public func getAccountInfo(
        publicKey: PublicKey,
        commitment: Commitment? = nil,
        completion: @escaping (Result<AccountInfo<Data>?, Error>) -> Void
    ) {
        getAccountInfoAndContext(publicKey: publicKey, commitment: commitment) { result in
            completion(result.map { $0.value })
        }
    }

    /// Fetch all the account info for multiple accounts specified by an array of public keys, return with context
    // TODO: public func getMultipleAccountsInfoAndContext

    /// Fetch all the account info for multiple accounts specified by an array of public keys
    // TODO: public func getMultipleAccountsInfo

    /// Returns epoch activation information for a stake account that has been delegated
    // TODO: public func getStakeActivation

    /// Fetch all the accounts owned by the specified program id
    // TODO: public func getProgramAccounts

    /// Fetch and parse all the accounts owned by the specified program id
    // TODO: public func getParsedProgramAccounts

    /// Confirm the transaction identified by the specified signature.
    // TODO: public func confirmTransaction

    /// Return the list of nodes that are currently participating in the cluster
    // TODO: public func getClusterNodes

    /// Return the list of nodes that are currently participating in the cluster
    // TODO: public func getVoteAccounts

    /// Fetch the current slot that the node is processing
    // TODO: public func getSlot

    /// Fetch the current slot leader of the cluster
    // TODO: public func getSlotLeader

    /// Fetch `limit` number of slot leaders starting from `startSlot`
    // TODO: public func getSlotLeaders

    /// Fetch the current status of a signature
    // TODO: public func getSignatureStatus

    /// Fetch the current statuses of a batch of signatures
    // TODO: public func getSignatureStatuses

    /// Fetch the current transaction count of the cluster
    // TODO: public func getTransactionCount

    /// Fetch the cluster InflationGovernor parameters
    // TODO: public func getInflationGovernor

    /// Fetch the inflation reward for a list of addresses for an epoch
    // TODO: public func getInflationReward

    /// Fetch the Epoch Info parameters
    // TODO: public func getEpochInfo

    /// Fetch the Epoch Schedule parameters
    // TODO: public func getEpochSchedule

    /// Fetch the leader schedule for the current epoch
    // TODO: public func getLeaderSchedule

    /// Fetch the minimum balance needed to exempt an account of `dataLength`
    /// size from rent
    // TODO: public func getMinimumBalanceForRentExemption

    /// Fetch a recent blockhash from the cluster, return with context
    // TODO: public func getRecentBlockhashAndContext

    /// Fetch recent performance samples
    // TODO: public func getRecentPerformanceSamples

    /// Fetch the fee for a message from the cluster, return with context
    // TODO: public func getFeeForMessage

    /// Fetch the latest blockhash from the cluster
    // TODO: public func getLatestBlockhash

    /// Fetch the latest blockhash from the cluster
    // TODO: public func getLatestBlockhashAndContext

    /// Fetch the node version
    // TODO: public func getVersion

    /// Fetch the genesis hash
    // TODO: public func getGenesisHash

    /// Fetch a processed block from the cluster.
    // TODO: public func getBlock

    /// Fetch a confirmed or finalized transaction from the cluster.
    // TODO: public func getTransaction

    /// Fetch parsed transaction details for a confirmed or finalized transaction
    // TODO: public func getParsedTransaction

    /// Fetch parsed transaction details for a batch of confirmed transactions
    // TODO: public func getParsedTransactions

    /// Fetch confirmed blocks between two slots
    // TODO: public func getBlocks

    /// Fetch a list of Signatures from the cluster for a block, excluding rewards
    // TODO: public func getBlockSignatures

    /// Returns confirmed signatures for transactions involving an
    /// address backwards in time from the provided signature or most recent confirmed block
    // TODO: public func getConfirmedSignaturesForAddress2

    /// Returns confirmed signatures for transactions involving an
    /// address backwards in time from the provided signature or most recent confirmed block
    // TODO: public func getSignaturesForAddress

    /// Fetch the contents of a Nonce account from the cluster, return with context
    // TODO: public func getNonceAndContext

    /// Fetch the contents of a Nonce account from the cluster
    // TODO: public func getNonce

    /// Request an allocation of lamports to the specified address
    // TODO: public func requestAirdrop

    /// Simulate a transaction
    // TODO: public func simulateTransaction

    /// Sign and send a transaction
    // TODO: public func sendTransaction

    /// Send a transaction that has already been signed and serialized into the
    /// wire format
    // TODO: public func sendRawTransaction

    /// Send a transaction that has already been signed, serialized into the
    /// wire format, and encoded as a base64 string
    // TODO: public func sendEncodedTransaction
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
