//
//  ClusterTests.swift
//  
//
//  Created by Scott on 2022/3/30.
//

import XCTest
import SolanaWeb3

final class ClusterTests: XCTestCase {

    func testDevnet() throws {
        XCTAssertEqual(Cluster.clusterApiURL(), URL(string: "https://api.devnet.solana.com")!)
        XCTAssertEqual(Cluster.clusterApiURL(cluster: .devnet), URL(string: "https://api.devnet.solana.com")!)
        XCTAssertEqual(Cluster.clusterApiURL(cluster: .devnet, tls: true), URL(string: "https://api.devnet.solana.com")!)
        XCTAssertEqual(Cluster.clusterApiURL(cluster: .devnet, tls: false), URL(string: "http://api.devnet.solana.com")!)
    }

}
