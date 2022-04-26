//
//  Connection.swift
//  SolanaWeb3
//
//  Created by Scott on 2022/3/30.
//

import Foundation
import Alamofire

let blockhashCacheTimeout: TimeInterval = 30 // 30s

public class Connection {

    public let endpointURL: URL
    public let commitment: Commitment?
    public let session: Session

    private var disableBlockhashCaching: Bool = false
    private var blockhashInfo = BlockhashInfo()
    private var pollNewBlockhashTimer: Timer?
    private var pollNewBlockhashRepeatCount: Int = 0
    private var pollNewBlockhashCompletions: [Date: ((Result<Blockhash, Error>) -> Void)] = [:]

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
                debugPrint(String(data: data, encoding: .utf8) ?? "empty")
                completion(.success(data))
            case let .failure(error):
                completion(.failure(.networkError(error)))
            }
        }
        request.cURLDescription { info in
            debugPrint(info)
        }
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

    public func getSupply(
        commitment: Commitment? = nil,
        completion: @escaping (Result<RpcResponseAndContext<Supply>, Error>) -> Void
    ) {
        let config = GetSupplyConfig(commitment: commitment)
        getSupply(config: config, completion: completion)
    }


    /// Fetch information about the current supply
    /// - Parameters:
    ///  - commitment: The level of commitment desired
    ///  - excludeNonCirculatingAccountsList: Exclude non circulating accounts list from response
    public func getSupply(
        config: GetSupplyConfig? = nil,
        completion: @escaping (Result<RpcResponseAndContext<Supply>, Error>) -> Void
    ) {
        let config = GetSupplyConfig(
            commitment: config?.commitment ?? self.commitment,
            excludeNonCirculatingAccountsList: config?.excludeNonCirculatingAccountsList)
        let args: [Encodable] = [config]
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
        completion: @escaping (Result<RpcResponseAndContext<KeyAccountInfoPair<Data>>, Error>) -> Void
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
//    public func getParsedTokenAccountsByOwner(
//        ownerAddress: PublicKey,
//        filter: TokenAccountsFilter,
//        commitment: Commitment? = nil,
//        completion: @escaping (Result<RpcResponseAndContext<[KeyAccountInfoPair<ParsedAccountData<Data>>]>, Error>) -> Void
//    ) {
//        var args: [Encodable] = [ownerAddress.base58]
//        switch filter {
//        case .mint(let publicKey):
//            args.append(["mint": publicKey.base58])
//        case .programId(let publicKey):
//            args.append(["programId": publicKey.base58])
//        }
//        if let config = RpcRequestConfiguration(commitment: commitment ?? self.commitment, encoding: .jsonParsed) {
//            args.append(config)
//        }
//        sendRpcRequest(
//            method: "getTokenAccountsByOwner",
//            args: args,
//            completion: completion)
//    }

    /// Fetch the 20 largest accounts with their current balances
    ///
    /// - Parameters:
    ///   - commitment: The level of commitment desired
    ///   - filter: Filter largest accounts by whether they are part of the circulating supply
    public func getLargestAccounts(
        commitment: Commitment? = nil,
        filter: LargestAccountsFilter? = nil,
        completion: @escaping (Result<RpcResponseAndContext<[AccountBalancePair]>, Error>) -> Void
    ) {
        var args: [Encodable] = []
        if let config = RpcRequestConfiguration(
            commitment: commitment ?? self.commitment,
            extra: filter != nil ? ["filter": filter] : nil) {
            args.append(config)
        }
        sendRpcRequest(
            method: "getLargestAccounts",
            args: args,
            completion: completion)
    }

    /// Fetch the 20 largest token accounts with their current balances
    /// for a given mint.
    public func getTokenLargestAccounts(
        mintAddress: PublicKey,
        commitment: Commitment? = nil,
        completion: @escaping (Result<RpcResponseAndContext<[TokenAccountBalancePair]>, Error>) -> Void
    ) {
        var args: [Encodable] = [mintAddress.base58]
        if let config = RpcRequestConfiguration(commitment: commitment ?? self.commitment) {
            args.append(config)
        }
        sendRpcRequest(
            method: "getTokenLargestAccounts",
            args: args,
            completion: completion)
    }

    /// Fetch all the account info for the specified public key, return with context
    public func getAccountInfoAndContext(
        publicKey: PublicKey,
        commitment: Commitment? = nil,
        completion: @escaping (Result<RpcResponseAndContext<AccountInfo<Data>?>, Error>) -> Void
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
//    public func getParsedAccountInfo(
//        publicKey: PublicKey,
//        commitment: Commitment? = nil,
//        completion: @escaping (Result<RpcResponseAndContext<AccountInfo<ParsedAccountData<Data>>?>, Error>) -> Void
//    ) {
//        var args: [Encodable] = [publicKey.base58]
//        if let config = RpcRequestConfiguration(commitment: commitment ?? self.commitment, encoding: .jsonParsed) {
//            args.append(config)
//        }
//        sendRpcRequest(
//            method: "getAccountInfo",
//            args: args,
//            completion: completion)
//    }

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
    public func getMultipleAccountsInfoAndContext(
        publicKeys: [PublicKey],
        commitment: Commitment? = nil,
        completion: @escaping (Result<[RpcResponseAndContext<AccountInfo<Data>?>], Error>) -> Void
    ) {
        var args: [Encodable] = [publicKeys.map(\.base58)]
        if let config = RpcRequestConfiguration(commitment: commitment ?? self.commitment, encoding: .base64) {
            args.append(config)
        }
        sendRpcRequest(
            method: "getMultipleAccounts",
            args: args,
            completion: completion)
    }

    /// Fetch all the account info for multiple accounts specified by an array of public keys
    public func getMultipleAccountsInfo(
        publicKeys: [PublicKey],
        commitment: Commitment? = nil,
        completion: @escaping (Result<[AccountInfo<Data>?], Error>) -> Void
    ) {
        getMultipleAccountsInfoAndContext(
            publicKeys: publicKeys,
            commitment: commitment) { result in
                completion(result.map { $0.map { $0.value } })
            }
    }

    /// Returns epoch activation information for a stake account that has been delegated
    public func getStakeActivation(
        publicKey: PublicKey,
        commitment: Commitment? = nil,
        epoch: UInt64? = nil,
        completion: @escaping (Result<StakeActivationData, Error>) -> Void
    ) {
        var args: [Encodable] = [publicKey.base58]
        if let config = RpcRequestConfiguration(
            commitment: commitment ?? self.commitment,
            extra: epoch != nil ? ["epoch": epoch] : nil
        ) {
            args.append(config)
        }
        sendRpcRequest(
            method: "getStakeActivation",
            args: args,
            completion: completion)
    }

    /// Fetch all the accounts owned by the specified program id
    public func getProgramAccounts(
        programId: PublicKey,
        commitment: Commitment? = nil,
        encoding: RpcRequestEncoding? = nil,
        dataSlice: DataSlice? = nil,
        filters: [GetProgramAccountsFilter]? = nil,
        completion: @escaping (Result<[KeyAccountInfoPair<Data>], Error>) -> Void
    ) {
        var args: [Encodable] = [programId.base58]
        var extra: [String: Encodable] = [:]
        if let dataSlice = dataSlice {
            extra["dataSlice"] = dataSlice
        }
        if let filters = filters {
            extra["filters"] = filters
        }
        if let config = RpcRequestConfiguration(
            commitment: commitment ?? self.commitment,
            encoding: encoding ?? .base64,
            extra: extra
        ) {
            args.append(config)
        }
        sendRpcRequest(
            method: "getProgramAccounts",
            args: args,
            completion: completion)
    }

    /// Fetch and parse all the accounts owned by the specified program id
    ///
    /// - Parameters:
    ///  - commitment: commitment level
    ///  - filters: array of filters to apply to accounts
//    public func getParsedProgramAccounts(
//        programId: PublicKey,
//        commitment: Commitment? = nil,
//        filters: [GetProgramAccountsFilter]? = nil,
//        completion: @escaping (Result<[KeyAccountInfoPair<ParsedAccountData<Data>>], Error>) -> Void
//    ) {
//        var args: [Encodable] = [programId.base58]
//        if let config = RpcRequestConfiguration(
//            commitment: commitment ?? self.commitment,
//            encoding: .jsonParsed,
//            extra: filters != nil ? ["filters": filters] : nil
//        ) {
//            args.append(config)
//        }
//        sendRpcRequest(
//            method: "getProgramAccounts",
//            args: args,
//            completion: completion)
//    }

    /// Confirm the transaction identified by the specified signature.
    /// public func confirmTransaction
    // TODO: not completed

    /// Return the list of nodes that are currently participating in the cluster
    public func getClusterNodes(
        completion: @escaping (Result<[ContactInfo], Error>) -> Void
    ) {
        sendRpcRequest(
            method: "getClusterNodes",
            args: [],
            completion: completion)
    }

    /// Return the list of nodes that are currently participating in the cluster
    public func getVoteAccounts(
        commitment: Commitment?,
        completion: @escaping (Result<[ContactInfo], Error>) -> Void
    ) {
        var args: [Encodable] = []
        if let config = RpcRequestConfiguration(commitment: commitment ?? self.commitment) {
            args.append(config)
        }
        sendRpcRequest(
            method: "getVoteAccounts",
            args: args,
            completion: completion)
    }

    /// Fetch the current slot that the node is processing
    public func getSlot(
        commitment: Commitment? = nil,
        completion: @escaping (Result<UInt64, Error>) -> Void
    ) {
        var args: [Encodable] = []
        if let config = RpcRequestConfiguration(commitment: commitment ?? self.commitment) {
            args.append(config)
        }
        sendRpcRequest(
            method: "getSlot",
            args: args,
            completion: completion)
    }

    /// Fetch the current slot leader of the cluster
    public func getSlotLeader(
        commitment: Commitment? = nil,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        var args: [Encodable] = []
        if let config = RpcRequestConfiguration(commitment: commitment ?? self.commitment) {
            args.append(config)
        }
        sendRpcRequest(
            method: "getSlotLeader",
            args: args,
            completion: completion)
    }

    /// Fetch `limit` number of slot leaders starting from `startSlot`
    public func getSlotLeaders(
        startSlot: UInt64,
        limit: UInt64,
        completion: @escaping (Result<[PublicKey], Error>) -> Void
    ) {
        let args = [startSlot, limit]
        sendRpcRequest(
            method: "getSlotLeader",
            args: args,
            completion: completion)
    }

    /// Fetch the current status of a signature
    public func getSignatureStatus(
        signature: SignatureStatus,
        config: SignatureStatusConfig?,
        completion: @escaping (Result<RpcResponseAndContext<SignatureStatus?>, Error>) -> Void
    ) {
        getSignatureStatuses(
            signatures: [signature],
            config: config) { result in
                switch result {
                case let .success(response):
                    let signatureStatus: SignatureStatus?
                    if let value = response.value.first {
                        signatureStatus = value
                    } else {
                        signatureStatus = nil
                    }
                    let newResponse = RpcResponseAndContext(context: response.context, value: signatureStatus)
                    completion(.success(newResponse))
                case let .failure(error):
                    completion(.failure(error))
                }
            }
    }

    /// Fetch the current statuses of a batch of signatures
    public func getSignatureStatuses(
        signatures: [SignatureStatus],
        config: SignatureStatusConfig?,
        completion: @escaping (Result<RpcResponseAndContext<[SignatureStatus?]>, Error>) -> Void
    ) {
        var args: [Encodable] = [signatures]
        if let config = config {
            args.append(config)
        }
        sendRpcRequest(
            method: "getSignatureStatuses",
            args: args,
            completion: completion)
    }

    /// Fetch the current transaction count of the cluster
    public func getTransactionCount(
        commitment: Commitment? = nil,
        completion: @escaping (Result<UInt64, Error>) -> Void
    ) {
        var args: [Encodable] = []
        if let config = RpcRequestConfiguration(commitment: commitment ?? self.commitment) {
            args.append(config)
        }
        sendRpcRequest(
            method: "getTransactionCount",
            args: args,
            completion: completion)
    }

    /// Fetch the cluster InflationGovernor parameters
    public func getInflationGovernor(
        commitment: Commitment? = nil,
        completion: @escaping (Result<InflationGovernor, Error>) -> Void
    ) {
        var args: [Encodable] = []
        if let config = RpcRequestConfiguration(commitment: commitment ?? self.commitment) {
            args.append(config)
        }
        sendRpcRequest(
            method: "getInflationGovernor",
            args: args,
            completion: completion)
    }

    /// Fetch the inflation reward for a list of addresses for an epoch
    public func getInflationReward(
        addresses: [PublicKey],
        epoch: UInt64? = nil,
        commitment: Commitment? = nil,
        completion: @escaping (Result<[InflationReward?], Error>) -> Void
    ) {
        var args: [Encodable] = [addresses.map(\.base58)]
        if let config = RpcRequestConfiguration(
            commitment: commitment ?? self.commitment,
            extra: epoch != nil ? ["epoch": epoch] : nil
        ) {
            args.append(config)
        }
        sendRpcRequest(
            method: "getInflationReward",
            args: args,
            completion: completion)
    }

    /// Fetch the Epoch Info parameters
    public func getEpochInfo(
        commitment: Commitment? = nil,
        completion: @escaping (Result<EpochInfo, Error>) -> Void
    ) {
        var args: [Encodable] = []
        if let config = RpcRequestConfiguration(commitment: commitment ?? self.commitment) {
            args.append(config)
        }
        sendRpcRequest(
            method: "getEpochInfo",
            args: args,
            completion: completion)
    }

    /// Fetch the Epoch Schedule parameters
    public func getEpochSchedule(
        completion: @escaping (Result<EpochSchedule, Error>) -> Void
    ) {
        sendRpcRequest(
            method: "getEpochSchedule",
            args: [],
            completion: completion)
    }

    /// Fetch the leader schedule for the current epoch
    public func getLeaderSchedule(
        completion: @escaping (Result<LeaderSchedule, Error>) -> Void
    ) {
        sendRpcRequest(
            method: "getLeaderSchedule",
            args: [],
            completion: completion)
    }

    /// Fetch the minimum balance needed to exempt an account of `dataLength`
    /// size from rent
    public func getMinimumBalanceForRentExemption(
        dataLength: UInt64,
        commitment: Commitment? = nil,
        completion: @escaping (Result<UInt64, Error>) -> Void
    ) {
        var args: [Encodable] = [dataLength]
        if let config = RpcRequestConfiguration(commitment: commitment ?? self.commitment) {
            args.append(config)
        }
        sendRpcRequest(
            method: "getMinimumBalanceForRentExemption",
            args: args,
            completion: completion)
    }

    /// Fetch recent performance samples
    public func getRecentPerformanceSamples(
        limit: UInt64? = nil,
        completion: @escaping (Result<[PerfSample], Error>) -> Void
    ) {
        var args: [Encodable] = []
        if let limit = limit {
            args.append(limit)
        }
        sendRpcRequest(
            method: "getRecentPerformanceSamples",
            args: args,
            completion: completion)
    }

    /// Fetch the fee for a message from the cluster, return with context
    public func getFeeForMessage(
        message: Message,
        commitment: Commitment? = nil,
        completion: @escaping (Result<RpcResponseAndContext<UInt64>, Error>) -> Void
    ) {
        let wireMessage = message.serialize().base64EncodedString()
        var args: [Encodable] = [wireMessage]
        if let config = RpcRequestConfiguration(commitment: commitment ?? self.commitment) {
            args.append(config)
        }
        sendRpcRequest(
            method: "getFeeForMessage",
            args: args,
            completion: completion)
    }

    /// Fetch the latest blockhash from the cluster
    public func getLatestBlockhash(
        commitment: Commitment? = nil,
        completion: @escaping (Result<BlockhashLastValidBlockHeightPair, Error>) -> Void
    ) {
        getLatestBlockhashAndContext(
            commitment: commitment) { result in
                completion(result.map(\.value))
            }
    }

    /// Fetch the latest blockhash from the cluster
    public func getLatestBlockhashAndContext(
        commitment: Commitment? = nil,
        completion: @escaping (Result<RpcResponseAndContext<BlockhashLastValidBlockHeightPair>, Error>) -> Void
    ) {
        var args: [Encodable] = []
        if let config = RpcRequestConfiguration(commitment: commitment ?? self.commitment) {
            args.append(config)
        }
        sendRpcRequest(
            method: "getLatestBlockhash",
            args: args,
            completion: completion)
    }

    /// Fetch the node version
    public func getVersion(completion: @escaping (Result<Version, Error>) -> Void) {
        sendRpcRequest(
            method: "getVersion",
            args: [],
            completion: completion)
    }

    /// Fetch the genesis hash
    public func getGenesisHash(completion: @escaping (Result<String, Error>) -> Void) {
        sendRpcRequest(
            method: "getGenesisHash",
            args: [],
            completion: completion)
    }

    /// Fetch a processed block from the cluster.
    public func getBlock(
        slot: UInt64,
        commitment: Finality? = nil,
        completion: @escaping (Result<BlockResponse?, Error>) -> Void
    ) {
        var args: [Encodable] = [slot]
        if let config = RpcRequestConfiguration(finality: commitment ?? self.commitment?.toFinality) {
            args.append(config)
        }
        sendRpcRequest(
            method: "getBlock",
            args: args,
            completion: completion)
    }

    /// Returns the current block height of the node
    public func getBlockHeight(
        commitment: Commitment?,
        completion: @escaping (Result<UInt64, Error>) -> Void
    ) {
        var args: [Encodable] = []
        if let config = RpcRequestConfiguration(commitment: commitment ?? self.commitment) {
            args.append(config)
        }
        sendRpcRequest(
            method: "getBlockHeight",
            args: args,
            completion: completion)
    }

    /// Returns recent block production information from the current or previous epoch
    public func getBlockProduction(
        config: GetBlockProductionConfig,
        completion: @escaping (Result<RpcResponseAndContext<BlockProduction>, Error>) -> Void
    ) {
        let config = GetBlockProductionConfig(
            commitment: config.commitment ?? self.commitment,
            range: config.range,
            identity: config.identity)
        var args: [Encodable] = []
        if let config = RpcRequestConfiguration(
            commitment: config.commitment ?? self.commitment,
            encoding: .base64,
            extra: ["identity": config.identity, "range": config.range]) {
            args.append(config)
        }
        sendRpcRequest(
            method: "getBlockProduction",
            args: args,
            completion: completion)
    }

    /// Fetch a confirmed or finalized transaction from the cluster.
    public func getTransaction(
        signature: String,
        commitment: Finality? = nil,
        completion: @escaping (Result<RpcResponseAndContext<TransactionResponse?>, Error>) -> Void
    ) {
        var args: [Encodable] = [signature]
        if let config = RpcRequestConfiguration(finality: commitment ?? self.commitment?.toFinality) {
            args.append(config)
        }
        sendRpcRequest(
            method: "getTransaction",
            args: args,
            completion: completion)
    }

    /// Fetch parsed transaction details for a confirmed or finalized transaction
    public func getParsedTransaction(
        signature: TransactionSignature,
        commitment: Finality? = nil,
        completion: @escaping (Result<ParsedTransactionWithMeta<Data>?, Error>) -> Void
    ) {
        var args: [Encodable] = [signature]
        if let config = RpcRequestConfiguration(
            finality: commitment ?? self.commitment?.toFinality,
            encoding: .jsonParsed) {
            args.append(config)
        }
        sendRpcRequest(
            method: "getTransaction",
            args: args,
            completion: completion)
    }

    /// Fetch parsed transaction details for a batch of confirmed transactions
    public func getParsedTransactions(
        signatures: [TransactionSignature],
        commitment: Finality? = nil,
        completion: @escaping (Result<[ParsedTransactionWithMeta<Data>?], Error>) -> Void
    ) {
        let batch: [RpcParams] = signatures.map { signature in
            var args: [Encodable] = [signature]
            if let config = RpcRequestConfiguration(
                finality: commitment ?? self.commitment?.toFinality,
                encoding: .jsonParsed) {
                args.append(config)
            }
            return RpcParams(methodName: "getTransaction", args: args)
        }
        sendRpcRequest(
            method: "getTransaction",
            args: batch,
            completion: completion)
    }

    /// Fetch confirmed blocks between two slots
    public func getBlocks(
        startSlot: UInt64,
        endSlot: UInt64? = nil,
        commitment: Finality? = nil,
        completion: @escaping (Result<[UInt64], Error>) -> Void
    ) {
        var args: [Encodable] = [startSlot]
        if let endSlot = endSlot {
            args.append(endSlot)
        }
        if let config = RpcRequestConfiguration(finality: commitment ?? self.commitment?.toFinality) {
            args.append(config)
        }
        sendRpcRequest(
            method: "getBlocks",
            args: args,
            completion: completion)
    }

    /// Fetch a list of Signatures from the cluster for a block, excluding rewards
    public func getBlockSignatures(
        slot: UInt64,
        commitment: Finality? = nil,
        completion: @escaping (Result<BlockSignatures, Error>) -> Void
    ) {
        var args: [Encodable] = [slot]
        if let config = RpcRequestConfiguration(
            finality: commitment ?? self.commitment?.toFinality,
            extra: ["transactionDetails": "signatures", "rewards": false]
        ) {
            args.append(config)
        }
        sendRpcRequest(
            method: "getBlocks",
            args: args,
            completion: completion)
    }

    /// Returns confirmed signatures for transactions involving an
    /// address backwards in time from the provided signature or most recent confirmed block
    public func getConfirmedSignaturesForAddress2(
        address: PublicKey,
        options: ConfirmedSignaturesForAddress2Options? = nil,
        commitment: Finality? = nil,
        completion: @escaping (Result<[ConfirmedSignatureInfo], Error>) -> Void
    ) {
        var args: [Encodable] = [address.base58]
        var extra: [String: Encodable] = [:]
        if let options = options {
            let mirror = Mirror(reflecting: options)
            mirror.children.forEach {
                guard let key = $0.label, let value = $0.value as? Encodable else { return }
                extra[key] = value
            }
        }
        if let config = RpcRequestConfiguration(
            finality: commitment ?? self.commitment?.toFinality,
            extra: extra
        ) {
            args.append(config)
        }
        sendRpcRequest(
            method: "getConfirmedSignaturesForAddress2",
            args: args,
            completion: completion)
    }

    /// Returns confirmed signatures for transactions involving an
    /// address backwards in time from the provided signature or most recent confirmed block
    public func getSignaturesForAddress(
        address: PublicKey,
        options: SignaturesForAddressOptions? = nil,
        commitment: Finality? = nil,
        completion: @escaping (Result<[ConfirmedSignatureInfo], Error>) -> Void
    ) {
        let args: [Encodable] = [address.base58]
        var extra: [String: Encodable] = [:]
        if let options = options {
            let mirror = Mirror(reflecting: options)
            mirror.children.forEach {
                guard let key = $0.label, let value = $0.value as? Encodable else { return }
                extra[key] = value
            }
        }
        sendRpcRequest(
            method: "getSignaturesForAddress",
            args: args,
            completion: completion)
    }

    /// Fetch the contents of a Nonce account from the cluster, return with context
    public func getNonceAndContext(
        nonceAccount: PublicKey,
        commitment: Commitment? = nil,
        completion: @escaping (Result<RpcResponseAndContext<NonceAccount?>, Error>) -> Void
    ) {
        getAccountInfoAndContext(publicKey: nonceAccount, commitment: commitment) { result in
            switch result {
            case let .success(response):
                var value: NonceAccount? = nil
                if let data = response.value?.data {
                    var index = 0
                    do {
                        let layout = try NonceAccountLayout(buffer: data, pointer: &index)
                        value = NonceAccount(
                            authorizedPublicKey: layout.authorizedPublicKey,
                            nonce: layout.nonce.base58,
                            feeCalculator: layout.feeCalculator)
                    } catch {
                        completion(.failure(.unexpected(error)))
                    }
                }
                
                completion(.success(RpcResponseAndContext(context: response.context, value: value)))
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }

    /// Fetch the contents of a Nonce account from the cluster
    public func getNonce(
        nonceAccount: PublicKey,
        commitment: Commitment? = nil,
        completion: @escaping (Result<NonceAccount?, Error>) -> Void
    ) {
        getNonceAndContext(
            nonceAccount: nonceAccount,
            commitment: commitment) { result in
                completion(result.map(\.value))
            }
    }

    /// Request an allocation of lamports to the specified address
    public func requestAirdrop(
        to: PublicKey,
        lamports: UInt64,
        completion: @escaping (Result<TransactionSignature, Error>) -> Void
    ) {
        let args: [Encodable] = [to.base58, lamports]
        sendRpcRequest(
            method: "requestAirdrop",
            args: args,
            completion: completion)
    }

    /// Simulate a transaction
    public func simulateTransaction(
        transaction: Transaction,
        signers: [Signer] = [],
        includeAccounts: [PublicKey]? = nil,
        completion: @escaping (Result<RpcResponseAndContext<SimulatedTransactionResponse>, Error>) -> Void
    ) {
        var transaction = transaction
        if transaction.nonceInfo != nil && signers.isEmpty == false {
            do {
                try transaction.sign(signers)
            } catch {
                return completion(.failure(.unexpected(error)))
            }

            sendSimulateTransaction(
                transaction: transaction,
                signers: signers,
                includeAccounts: includeAccounts,
                completion: completion)
        } else {
            simulateTransactionWithRecentBlockhash(
                disableCache: disableBlockhashCaching,
                transaction: transaction,
                signers: signers,
                includeAccounts: includeAccounts,
                completion: completion)
        }
    }

    /// Simulate a transaction
    public func simulateTransaction(
        message: Message,
        signers: [Signer] = [],
        includeAccounts: [PublicKey]? = nil,
        completion: @escaping (Result<RpcResponseAndContext<SimulatedTransactionResponse>, Error>) -> Void
    ) {
        let transaction = Transaction(message: message)
        simulateTransaction(
            transaction: transaction,
            signers: signers,
            includeAccounts: includeAccounts,
            completion: completion)
    }

    private func simulateTransactionWithRecentBlockhash(
        disableCache: Bool,
        transaction: Transaction,
        signers: [Signer] = [],
        includeAccounts: [PublicKey]? = nil,
        completion: @escaping (Result<RpcResponseAndContext<SimulatedTransactionResponse>, Error>) -> Void
    ) {
        var transaction = transaction
        recentBlockhash(disableCache: disableCache) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case let .success(blockhash):
                transaction.recentBlockhash = blockhash

                do {
                    if signers.isEmpty == false {
                        try transaction.sign(signers)
                        guard let signature = transaction.signature else {
                            return completion(.failure(.noSignature))
                        }

                        let signatureBase64 = signature.base64EncodedString()
                        if self.blockhashInfo.simulatedSignatures.contains(signatureBase64) == false &&
                            self.blockhashInfo.transactionSignatures.contains(signatureBase64) == false {
                            self.blockhashInfo.simulatedSignatures.append(signatureBase64)
                        } else {
                            self.simulateTransactionWithRecentBlockhash(
                                disableCache: true,
                                transaction: transaction,
                                signers: signers,
                                includeAccounts: includeAccounts,
                                completion: completion)
                        }
                    }

                    self.sendSimulateTransaction(
                        transaction: transaction,
                        signers: signers,
                        includeAccounts: includeAccounts,
                        completion: completion)
                } catch {
                    completion(.failure(.unexpected(error)))
                }
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }

    private func sendSimulateTransaction(
        transaction: Transaction,
        signers: [Signer] = [],
        includeAccounts: [PublicKey]? = nil,
        completion: @escaping (Result<RpcResponseAndContext<SimulatedTransactionResponse>, Error>) -> Void
    ) {
        do {
            var transaction = transaction
            let message = try transaction.compile()
            let signData = message.serialize()
            let wireTransaction = try transaction.serialize(signData: signData)
            let encodedTransaction = wireTransaction.base64EncodedString()
            var extra: [String: Encodable] = [
                "encoding": RpcRequestEncoding.base64,
                "commitment": self.commitment]

            if let includeAccounts = includeAccounts {
                struct AccountsValue: Encodable {
                    let encoding: RpcRequestEncoding
                    let addresses: [String]
                }
                let addresses = includeAccounts.isEmpty ? message.nonProgramIds : includeAccounts
                extra["accounts"] = AccountsValue(encoding: .base64, addresses: addresses.map(\.base58))
            }

            if signers.isEmpty == false {
                extra["sigVerify"] = true
            }

            var args: [Encodable] = [encodedTransaction]
            if let config = RpcRequestConfiguration(extra: extra) {
                args.append(config)
            }
            sendRpcRequest(
                method: "simulateTransaction",
                args: args,
                completion: completion)
        } catch {
            completion(.failure(.unexpected(error)))
        }
    }

    /// Sign and send a transaction
    public func sendTransaction(
        transaction: Transaction,
        signers: [Signer],
        options: SendOptions? = nil,
        completion: @escaping (Result<TransactionSignature, Error>) -> Void
    ) {
        var transaction = transaction
        if transaction.nonceInfo != nil {
            do {
                try transaction.sign(signers)
                let wireTransaction = try transaction.serialize()
                return sendRawTransaction(
                    rawTransaction: wireTransaction,
                    options: options,
                    completion: completion)
            } catch {
                completion(.failure(.unexpected(error)))
            }
        } else {
            sendTransactionWithRecentBlockhash(
                disableCache: disableBlockhashCaching,
                transaction: transaction,
                signers: signers,
                options: options,
                completion: completion)
        }
    }

    private func sendTransactionWithRecentBlockhash(
        disableCache: Bool,
        transaction: Transaction,
        signers: [Signer],
        options: SendOptions?,
        completion: @escaping (Result<TransactionSignature, Error>) -> Void
    ) {
        var transaction = transaction
        recentBlockhash(disableCache: disableCache) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case let .success(blockhash):
                transaction.recentBlockhash = blockhash
                do {
                    try transaction.sign(signers)
                    guard let signature = transaction.signature else {
                        return completion(.failure(.noSignature))
                    }
                    let signatureBase64 = signature.base64EncodedString()
                    if self.blockhashInfo.transactionSignatures.contains(signatureBase64) == false {
                        // The signature of this transaction has not been seen before with the
                        // current recentBlockhash, all done. Let's break
                        self.blockhashInfo.transactionSignatures.append(signatureBase64)

                        let wireTransaction = try transaction.serialize()
                        self.sendRawTransaction(
                            rawTransaction: wireTransaction,
                            options: options,
                            completion: completion)
                    } else {
                        // This transaction would be treated as duplicate (its derived signature
                        // matched to one of already recorded signatures).
                        // So, we must fetch a new blockhash for a different signature by disabling
                        // our cache not to wait for the cache expiration (BLOCKHASH_CACHE_TIMEOUT_MS).
                        self.sendTransactionWithRecentBlockhash(
                            disableCache: true,
                            transaction: transaction,
                            signers: signers,
                            options: options,
                            completion: completion)
                    }
                } catch {
                    completion(.failure(.unexpected(error)))
                }

            case let .failure(error):
                completion(.failure(error))
            }
        }
    }

    /// Send a transaction that has already been signed and serialized into the
    /// wire format
    public func sendRawTransaction(
        rawTransaction: Data,
        options: SendOptions? = nil,
        completion: @escaping (Result<TransactionSignature, Error>) -> Void
    ) {
        let encodedTransaction = rawTransaction.base64EncodedString()
        sendEncodedTransaction(
            encodedTransaction: encodedTransaction,
            options: options,
            completion: completion)
    }

    /// Send a transaction that has already been signed, serialized into the
    /// wire format, and encoded as a base64 string
    public func sendEncodedTransaction(
        encodedTransaction: String,
        options: SendOptions? = nil,
        completion: @escaping (Result<TransactionSignature, Error>) -> Void
    ) {
        var args: [Encodable] = [encodedTransaction]
        var extra: [String: Encodable] = [:]
        if let options = options {
            if let maxRetries = options.maxRetries {
                extra["maxRetries"] = maxRetries
            }
            if let skipPreflight = options.skipPreflight {
                extra["skipPreflight"] = skipPreflight
            }
            if let preflightCommitment = options.preflightCommitment ?? self.commitment {
                extra["preflightCommitment"] = preflightCommitment
            }
        }
        if let config = RpcRequestConfiguration(
            encoding: .base64,
            extra: extra) {
            args.append(config)
        }
        sendRpcRequest(
            method: "sendTransaction",
            args: args,
            completion: completion)
    }

    private func recentBlockhash(disableCache: Bool, completion: @escaping (Result<Blockhash, Error>) -> Void) {
        if disableCache == false {
            let timeSinceFetch = Date().timeIntervalSince(blockhashInfo.lastFetch)
            let expired = timeSinceFetch >= blockhashCacheTimeout
            if let recentBlockhash = blockhashInfo.recentBlockhash, expired == false {
                return completion(.success(recentBlockhash))
            }
        }

        pollNewBlockhash(completion: completion)
    }

    private func pollNewBlockhash(completion: @escaping (Result<Blockhash, Error>) -> Void) {
        pollNewBlockhashTimer?.invalidate()
        pollNewBlockhashCompletions[Date()] = completion
        pollNewBlockhashRepeatCount = 0
        pollNewBlockhashTimer = Timer.scheduledTimer(
            withTimeInterval: Timing.msPerSlot / 2,
            repeats: true,
            block: { [weak self] timer in
                guard let self = self else { return }
                guard self.pollNewBlockhashRepeatCount < 50 else {
                    timer.invalidate()
                    self.pollNewBlockhashCompletions.forEach { date, completion in
                        completion(.failure(.unableToObtainNewBlockhash(afterSeconds: Date().timeIntervalSince(date))))
                    }
                    self.pollNewBlockhashCompletions = [:]
                    self.pollNewBlockhashTimer = nil
                    return
                }

                self.getLatestBlockhash(commitment: .finalized) { [weak self, weak timer] result in
                    guard let self = self else { return }

                    switch result {
                    case let .success(pair):
                        if self.blockhashInfo.recentBlockhash != pair.blockhash {
                            self.blockhashInfo = BlockhashInfo(
                                recentBlockhash: pair.blockhash,
                                lastFetch: Date(),
                                simulatedSignatures: [],
                                transactionSignatures: [])
                            timer?.invalidate()
                            self.pollNewBlockhashCompletions.forEach { date, completion in
                                completion(.success(pair.blockhash))
                            }
                            self.pollNewBlockhashCompletions = [:]
                            self.pollNewBlockhashTimer = nil
                        }

                    case let .failure(error):
                        timer?.invalidate()
                        self.pollNewBlockhashCompletions.forEach { date, completion in
                            completion(.failure(error))
                        }
                        self.pollNewBlockhashCompletions = [:]
                        self.pollNewBlockhashTimer = nil
                    }
                }

                self.pollNewBlockhashRepeatCount += 1
            })
    }
}

// MARK: - Error
public extension Connection {

    enum Error: Swift.Error {
        case networkError(AFError)
        case decodingFailed(Swift.Error)
        case invalidResponse(ResponseError)
        case unknownResponse
        case unableToObtainNewBlockhash(afterSeconds: TimeInterval)
        case noSignature
        case invalidSignature
        case unexpected(Swift.Error)
    }
}

private struct RpcParams: Encodable {

    let methodName: String

    let args: [Encodable]

    enum CodingKeys: String, CodingKey {
        case methodName
        case args
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(methodName, forKey: .methodName)
        let wrappedArgs = args.map(EncodableWrapper.init(wrapped:))
        try container.encode(wrappedArgs, forKey: .args)
    }
}

private struct BlockhashInfo {

    public var recentBlockhash: Blockhash?

    public var lastFetch: Date = Date()

    public var simulatedSignatures: [String] = []

    public var transactionSignatures: [String] = []
}
