//
//  BufferLayoutProperty.swift
//  Blocto
//
//  Created by Scott on 2021/11/10.
//  Copyright © 2021 Portto Co., Ltd. All rights reserved.
//

import Foundation
import Runtime

public protocol BufferLayoutSerializable {
    func serialize() throws -> Data
}

public protocol BufferLayoutDeserializable {
    init(buffer: Data, pointer: inout Int) throws
}

public typealias BufferLayoutProperty = BufferLayoutSerializable & BufferLayoutDeserializable

extension Data: BufferLayoutProperty {

    public func serialize() throws -> Data { self }

    public init(buffer: Data, pointer: inout Int) throws {
        let size = buffer.count - pointer
        let data = Array(buffer[pointer..<pointer+size])
        self = Data(data)
        pointer += count
    }
}

extension UInt8: BufferLayoutProperty {}
extension UInt16: BufferLayoutProperty {}
extension UInt32: BufferLayoutProperty {}
extension UInt64: BufferLayoutProperty {}

extension Int8: BufferLayoutProperty {}
extension Int16: BufferLayoutProperty {}
extension Int32: BufferLayoutProperty {}
extension Int64: BufferLayoutProperty {}

extension FixedWidthInteger {

    public init(buffer: Data, pointer: inout Int) throws {
        let size = MemoryLayout<Self>.size
        guard buffer.count >= size else {
            throw BufferLayoutError.bytesLengthIsNotValid
        }
        let data = Array(buffer[pointer..<pointer+size])
        self = data.toUInt(ofType: Self.self)
        pointer += size
    }

    public func serialize() throws -> Data {
        var int = self
        return Data(bytes: &int, count: MemoryLayout<Self>.size)
    }
}

extension Bool: BufferLayoutProperty {

    public init(buffer: Data, pointer: inout Int) throws {
        guard buffer.count > pointer else {
            throw BufferLayoutError.bytesLengthIsNotValid
        }
        self = buffer[pointer] != 0
        pointer += 1
    }

    public func serialize() throws -> Data {
        var int: [UInt8] = [self ? 1: 0]
        return Data(bytes: &int, count: 1)
    }
}

extension Optional: BufferLayoutProperty where Wrapped: BufferLayoutProperty {

    public init(buffer: Data, pointer: inout Int) throws {
        guard let wrapped = try? Wrapped(buffer: buffer, pointer: &pointer) else {
            self = nil
            return
        }
        self = wrapped
    }

    public func serialize() throws -> Data {
        guard let self = self else { return Data() }
        return try self.serialize()
    }
}

extension Array where Element == UInt8 {

    func toUInt<T: FixedWidthInteger>(ofType: T.Type) -> T {
        let data = Data(self)
        return T(littleEndian: data.withUnsafeBytes { $0.load(as: T.self) })
    }

    func toInt() -> Int {
        var value: Int = 0
        for byte in self.reversed() {
            value = value << 8
            value = value | Int(byte)
        }
        return value
    }
}
