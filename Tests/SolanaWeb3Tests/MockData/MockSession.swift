//
//  File.swift
//  
//
//  Created by Scott on 2022/4/27.
//

import Foundation
import Mocker
import Alamofire

extension Session {

    static func makeMockSession() -> Session {
        let configuration = URLSessionConfiguration.af.default
        configuration.protocolClasses = [MockingURLProtocol.self] + (configuration.protocolClasses ?? [])
        return Session(configuration: configuration)
    }
}
