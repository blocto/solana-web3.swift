//
//  Shortvec.swift
//  SolanaWeb3
//
//  Created by Scott on 2022/3/18.
//

import Foundation

enum Shortvec {

    static func decodeLength(data: inout Data) -> Int {
        var len = 0
        var size = 0
        while true {
            guard let elem = data.popFirst() else { break }
            len |= ((Int(elem) & 0x7f) << (size * 7))
            size += 1
            if Int16(elem) & 0x80 == 0 {
                break
            }
        }
        return len
    }

    static func encodeLength(_ len: Int) -> Data {
        encodeLength(UInt(len))
    }

    static func encodeLength(_ len: UInt) -> Data {
        var remLen = len
        var bytes = Data()
        while true {
            var elem = remLen & 0x7f
            remLen >>= 7
            if remLen == 0 {
                bytes.append(UInt8(elem))
                break
            } else {
                elem |= 0x80
                bytes.append(UInt8(elem))
            }
        }
        return bytes
    }
}
