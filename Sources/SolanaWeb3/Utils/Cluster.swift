//
//  Cluster.swift
//  SolanaWeb3
//
//  Created by Scott on 2022/3/17.
//

import Foundation

public enum Cluster {
    case devnet
    case testnet
    case mainnetBeta

    var endpoint: String {
        switch self {
        case .devnet:
            return "api.devnet.solana.com"
        case .testnet:
            return "api.testnet.solana.com"
        case .mainnetBeta:
            return "api.mainnet-beta.solana.com"
        }
    }

    public func clusterApiURL(cluster: Cluster = .devnet, tls: Bool = true) -> URL {
        let schema = tls ? "https" : "http"
        let urlString = schema + "://" + cluster.endpoint
        return URL(string: urlString)!
    }
}
