//
//  PublicKeyTests.swift
//  SolanaWeb3
//
//  Created by Scott on 2022/3/14.
//

import XCTest
import SolanaWeb3

final class PublicKeyTests: XCTestCase {

    func testInvalidBytes() throws {
        XCTAssertThrowsError(try PublicKey(
            [3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
             0, 0, 0, 0, 0, 0, 0, 0, 0]))
    }

    func testInvalidStringCase1() throws {
        XCTAssertThrowsError(try PublicKey("0x300000000000000000000000000000000000000000000000000000000000000000000"))
    }

    func testInvalidStringCase2() throws {
        XCTAssertThrowsError(try PublicKey("0x300000000000000000000000000000000000000000000000000000000000000"))
    }

    func testInvalidStringCase3() throws {
        XCTAssertThrowsError(try PublicKey("135693854574979916511997248057056142015550763280047535983739356259273198796800000"))
    }

    func testInvalidStringCase4() throws {
        XCTAssertThrowsError(try PublicKey("12345"))
    }

    func testEqualCase1() throws {
        let publicKey1 = try PublicKey(
            [3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
             0, 0, 0, 0, 0, 0, 0])
        let publicKey2 = try PublicKey("CiDwVBFgWV9E5MvXWoLgnEgn2hK7rJikbvfWavzAQz3")

        XCTAssertEqual(publicKey1, publicKey2)
    }

    func testEqualCase2() throws {
        let publicKey1 = try PublicKey(
            [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
             0, 0, 0, 0, 0, 0, 1])
        let publicKey2 = try PublicKey(publicKey1.bytes)

        XCTAssertEqual(publicKey1, publicKey2)
    }

    func testBase58Case1() throws {
        let publicKey = try PublicKey("CiDwVBFgWV9E5MvXWoLgnEgn2hK7rJikbvfWavzAQz3")

        XCTAssertEqual(publicKey.base58, "CiDwVBFgWV9E5MvXWoLgnEgn2hK7rJikbvfWavzAQz3")
        XCTAssertEqual(publicKey.description, "CiDwVBFgWV9E5MvXWoLgnEgn2hK7rJikbvfWavzAQz3")
    }

    func testBase58Case2() throws {
        let publicKey = try PublicKey("1111111111111111111111111111BukQL")

        XCTAssertEqual(publicKey.base58, "1111111111111111111111111111BukQL")
        XCTAssertEqual(publicKey.description, "1111111111111111111111111111BukQL")
    }

    func testBase58Case3() throws {
        let publicKey = try PublicKey("11111111111111111111111111111111")

        XCTAssertEqual(publicKey.base58, "11111111111111111111111111111111")
        XCTAssertEqual(publicKey.description, "11111111111111111111111111111111")
    }

    func testBase58Case4() throws {
        let publicKey = try PublicKey([
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0])

        XCTAssertEqual(publicKey.base58, "11111111111111111111111111111111")
        XCTAssertEqual(publicKey.description, "11111111111111111111111111111111")
    }

}
