//
//  File.swift
//  
//
//  Created by Scott on 2022/4/5.
//

import Foundation

struct MockJsonRPCResponse<T: Codable>: Codable {
    let jsonrpc: String
    let result: T

    init(jsonrpc: String = "2.0", result: T) {
        self.jsonrpc = jsonrpc
        self.result = result
    }
}
