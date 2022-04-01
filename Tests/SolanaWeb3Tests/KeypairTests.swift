//
//  KeypairTests.swift
//  SolanaWeb3
//
//  Created by Scott on 2022/3/30.
//

import XCTest
import SolanaWeb3

final class KeypairTests: XCTestCase {

    func testNewKeypair() throws {
        let keypair = try Keypair()
        XCTAssertEqual(keypair.secretKey.count, 64)
        XCTAssertEqual(try keypair.publicKey.bytes.count, 32)
    }

    func testGenerateNewKeypair() throws {
        let keypair = try Keypair()
        XCTAssertEqual(keypair.secretKey.count, 64)
    }

    func testCreatingKeypairFromInvalidSecretKeyThrowsError() throws {
        let secretKey = Data(base64Encoded: "mdqVWeFekT7pqy5T49+tV12jO0m+ESW7ki4zSU9JiCgbL0kJbj5dvQ/PqcDAzZLZqzshVEs01d1KZdmLh4uZIG==")!
        XCTAssertThrowsError(try Keypair(secretKey: secretKey)) { error in
            XCTAssertEqual(error as? Keypair.Error, .providedSecretKeyIsInvalid)
        }
    }

    func testCreatingKeypairFromInvalidSecretKeySucceedsIfValidationIsSkipped() throws {
        let secretKey = Data(base64Encoded: "mdqVWeFekT7pqy5T49+tV12jO0m+ESW7ki4zSU9JiCgbL0kJbj5dvQ/PqcDAzZLZqzshVEs01d1KZdmLh4uZIG==")!
        let keypair = try Keypair(secretKey: secretKey, options: .init(skipValidation: true))
        XCTAssertEqual(try keypair.publicKey.base58, "2q7pyhPwAwZ3QMfZrnAbDhnh9mDUqycszcpf86VgQxhD")
    }

    func testGenerateKeypairFromRandomSeed() throws {
        let keypair = try Keypair(seed: Data(repeating: 8, count: 32))
        XCTAssertEqual(try keypair.publicKey.base58, "2KW2XRd9kwqet15Aha2oK3tYvd3nWbTFH1MBiRAv1BE1")
    }

}
