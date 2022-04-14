//
//  ConnectionRequestModelsTests.swift
//  SolanaWeb3
//
//  Created by Scott on 2022/4/12.
//

import XCTest
import SolanaWeb3

final class ConnectionRequestModelsTests: XCTestCase {

    func testEncodingWithAllNilValue() throws {
        let configuration = RpcRequestConfiguration()

        XCTAssertNil(configuration)
    }

    func testEncodingWithCommitment() throws {
        let configuration = RpcRequestConfiguration(commitment: .confirmed)
        let encoder = JSONEncoder()
        let encoded = try encoder.encode(configuration)
        let jsonText = String(data: encoded, encoding: .utf8)
        let expected = "{\"commitment\":\"confirmed\"}"

        XCTAssertEqual(jsonText, expected)
    }

    func testEncodingWithEncoding() throws {
        let configuration = RpcRequestConfiguration(encoding: .jsonParsed)
        let encoder = JSONEncoder()
        let encoded = try encoder.encode(configuration)
        let jsonText = String(data: encoded, encoding: .utf8)
        let expected = "{\"encoding\":\"jsonParsed\"}"

        XCTAssertEqual(jsonText, expected)
    }

    func testEncodingWithCommitmentAndEncoding() throws {
        let configuration = RpcRequestConfiguration(commitment: .confirmed, encoding: .jsonParsed)
        let encoder = JSONEncoder()
        let encoded = try encoder.encode(configuration)
        let jsonObject = try JSONSerialization.jsonObject(with: encoded, options: []) as? [String: String]
        let expected = ["encoding": "jsonParsed", "commitment": "confirmed"]

        XCTAssertEqual(jsonObject, expected)
    }

    func testEncodingWithExtra() throws {
        let configuration = RpcRequestConfiguration(
            extra: ["A": "B", "B": "C"])
        let encoder = JSONEncoder()
        let encoded = try encoder.encode(configuration)
        let jsonObject = try JSONSerialization.jsonObject(with: encoded, options: []) as? [String: String]
        let expected = ["A": "B", "B": "C"]

        XCTAssertEqual(jsonObject, expected)
    }

    func testEncodingWithCommitmentAndExtra() throws {
        let configuration = RpcRequestConfiguration(
            commitment: .confirmed,
            extra: ["A": "B", "B": "C"])
        let encoder = JSONEncoder()
        let encoded = try encoder.encode(configuration)
        let jsonObject = try JSONSerialization.jsonObject(with: encoded, options: []) as? [String: String]
        let expected = ["A": "B", "B": "C", "commitment": "confirmed"]

        XCTAssertEqual(jsonObject, expected)
    }

}
