//
//  ShortvecTests.swift
//  
//
//  Created by Scott on 2022/3/30.
//

import XCTest
import SolanaWeb3

final class ShortvecTests: XCTestCase {

    func testDecodeLength() throws {
        var data = Data()
        XCTAssertEqual(Shortvec.decodeLength(data: &data), 0)
        XCTAssertEqual(data.count, 0)

        data = Data([5])
        XCTAssertEqual(Shortvec.decodeLength(data: &data), 5)
        XCTAssertEqual(data.count, 0)

        data = Data([0x7f])
        XCTAssertEqual(Shortvec.decodeLength(data: &data), 0x7f)
        XCTAssertEqual(data.count, 0)

        data = Data([0x80, 0x01])
        XCTAssertEqual(Shortvec.decodeLength(data: &data), 0x80)
        XCTAssertEqual(data.count, 0)

        data = Data([0xff, 0x01])
        XCTAssertEqual(Shortvec.decodeLength(data: &data), 0xff)
        XCTAssertEqual(data.count, 0)

        data = Data([0x80, 0x02])
        XCTAssertEqual(Shortvec.decodeLength(data: &data), 0x100)
        XCTAssertEqual(data.count, 0)

        data = Data([0xff, 0xff, 0x01])
        XCTAssertEqual(Shortvec.decodeLength(data: &data), 0x7fff)
        XCTAssertEqual(data.count, 0)

        data = Data([0x80, 0x80, 0x80, 0x01])
        XCTAssertEqual(Shortvec.decodeLength(data: &data), 0x200000)
        XCTAssertEqual(data.count, 0)
    }

    func testEncodeLength() throws {
        
    }

}
