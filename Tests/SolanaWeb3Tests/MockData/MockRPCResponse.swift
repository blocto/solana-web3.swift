//
//  File.swift
//  
//
//  Created by Scott on 2022/4/27.
//

import Foundation

public struct MockRPCResponse: Encodable {

    let jsonrpc: String = "2.0"
    let id: String = ""
    let error: String?
    let result: Encodable?
    let withContext: Bool
    let slot: Int

    enum CodingKeys: String, CodingKey {
        case jsonrpc
        case id
        case error
        case result
    }

    public init(result: Encodable? = nil, error: String? = nil, withContext: Bool = false, slot: Int = 0) {
        self.result = result
        self.error = error
        self.withContext = withContext
        self.slot = slot
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(jsonrpc, forKey: .jsonrpc)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(error, forKey: .error)
        if withContext {
            try container.encode([
                "context": [
                    "slot": slot
                ],
                "value": result as Any
            ], forKey: .result)
        } else {
            let wrappedDict = result.map(EncodableWrapper.init(wrapped:))
            try container.encodeIfPresent(wrappedDict, forKey: .result)
        }
    }
}

struct EncodableWrapper: Encodable {
    let wrapped: Encodable

    func encode(to encoder: Encoder) throws {
        try self.wrapped.encode(to: encoder)
    }
}
