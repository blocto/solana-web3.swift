//
//  BufferLayoutError.swift
//  Blocto
//
//  Created by Scott on 2021/11/10.
//  Copyright © 2021 Portto Co., Ltd. All rights reserved.
//

import Foundation

public enum BufferLayoutError: Swift.Error {
    case bytesLengthIsNotValid
    case unsupportedType(type: Any.Type, propertyName: String)
    case layoutContainsAVectorWhoseLengthCanNotBePredefined
}
