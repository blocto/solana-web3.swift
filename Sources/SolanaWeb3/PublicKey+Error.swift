//
//  PublicKey+Error.swift
//  SolanaWeb3
//
//  Created by Scott on 2022/3/14.
//

import Foundation

public extension PublicKey {

    enum Error: Swift.Error {
        case invalidPublicKeyInput
        case invalidSeeds
        case maxSeedLengthExceeded
        case unableToFindViableProgramAddressNonce
    }
}
