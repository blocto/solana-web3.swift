//
//  BufferLayout.swift
//  Blocto
//
//  Created by Scott on 2021/11/10.
//  Copyright © 2021 Portto Co., Ltd. All rights reserved.
//

import Foundation
import Runtime

public protocol BufferLayout: BufferLayoutProperty {
    static func injectOtherProperties(typeInfo: TypeInfo, currentInstance: inout Self) throws
    static var excludedPropertyNames: [String] { get }
    static var span: UInt64 { get throws }
}

public extension BufferLayout {

    static var span: UInt64 {
        get throws {
            let info = try typeInfo(of: Self.self)

            var span: UInt64 = 0
            for property in info.properties {
                if Self.excludedPropertyNames.contains(property.name) {
                    continue
                }

                let instanceInfo = try typeInfo(of: property.type)
                if let t = instanceInfo.type as? Self.Type {
                    span += try t.span
                }
            }
            return span
        }
    }

    init(buffer: Data, pointer: inout Int) throws {
        let info = try typeInfo(of: Self.self)
        var selfInstance: Self = try createInstance()

        for property in info.properties {
            if Self.excludedPropertyNames.contains(property.name) {
                continue
            }

            let instanceInfo = try typeInfo(of: property.type)

            if let t = instanceInfo.type as? BufferLayoutDeserializable.Type {
                if pointer > buffer.count {
                    throw BufferLayoutError.bytesLengthIsNotValid
                }

                let newValue = try t.init(buffer: buffer, pointer: &pointer)

                let newProperty = try info.property(named: property.name)
                try newProperty.set(value: newValue, on: &selfInstance)
            }
        }
        try Self.injectOtherProperties(typeInfo: info, currentInstance: &selfInstance)
        self = selfInstance
    }

    func serialize() throws -> Data {
        let info = try typeInfo(of: Self.self)
        var data = Data()
        for property in info.properties {
            if Self.excludedPropertyNames.contains(property.name) {
                continue
            }

            let instance = try property.get(from: self)
            if let instance = instance as? BufferLayoutSerializable {
                data.append(try instance.serialize())
            }
        }
        return data
    }

    static func injectOtherProperties(typeInfo: TypeInfo, currentInstance: inout Self) throws { }
    static var excludedPropertyNames: [String] { [] }
}
