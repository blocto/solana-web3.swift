//
//  Transaction.swift
//  
//
//  Created by Scott on 2022/3/18.
//

import Foundation
import TweetNacl

/// Default (empty) signature
///
/// Signatures are 64 bytes in length
private let defaultSignature = Data(repeating: 0, count: signatureLength)

/// Maximum over-the-wire size of a Transaction
///
/// 1280 is IPv6 minimum MTU
/// 40 bytes is the size of the IPv6 header
/// 8 bytes is the size of the fragment header
private let packetDataSize = 1280 - 40 - 8

private let signatureLength = 64

/// Account metadata used to define instructions
public struct AccountMeta: Equatable {
    /// An account's public key
    public let publicKey: PublicKey

    /// True if an instruction requires a transaction signature matching `publicKey`
    public var isSigner: Bool

    /// True if the `publicKey` can be loaded as a read-write account.
    public var isWritable: Bool

    public init(publicKey: PublicKey, isSigner: Bool, isWritable: Bool) {
        self.publicKey = publicKey
        self.isSigner = isSigner
        self.isWritable = isWritable
    }
}

/// Configuration object for Transaction.serialize()
public struct SerializeConfig {
    /// Require all transaction signatures be present (default: true)
    public let requireAllSignatures: Bool

    /// Verify provided signatures (default: true)
    public let verifySignatures: Bool

    public init(requireAllSignatures: Bool = true, verifySignatures: Bool = true) {
        self.requireAllSignatures = requireAllSignatures
        self.verifySignatures = verifySignatures
    }
}

/// Transaction Instruction struct
public struct TransactionInstruction: Equatable {

    /// Public keys to include in this transaction
    /// Boolean represents whether this pubkey needs to sign the transaction
    public let keys: [AccountMeta]

    /// Program Id to execute
    public let programId: PublicKey

    /// Program input
    public let data: Data

    public init(keys: [AccountMeta], programId: PublicKey, data: Data? = nil) {
        self.keys = keys
        self.programId = programId
        self.data = data ?? Data()
    }
}

/// Pair of signature and corresponding public key
public struct SignaturePubkeyPair: Equatable {
    public var signature: Data?
    public let publicKey: PublicKey

    public init(signature: Data?, publicKey: PublicKey) {
        self.signature = signature
        self.publicKey = publicKey
    }
}

/// Nonce information to be used to build an offline Transaction.
public struct NonceInformation: Equatable {
    /// The current blockhash stored in the nonce
    public let nonce: Blockhash
    /// AdvanceNonceAccount Instruction
    public let nonceInstruction: TransactionInstruction

    public init(nonce: Blockhash, nonceInstruction: TransactionInstruction) {
        self.nonce = nonce
        self.nonceInstruction = nonceInstruction
    }
}

/// Transaction
public struct Transaction: Equatable {

    /// Signatures for the transaction.  Typically created by invoking the
    /// `sign()` method
    public var signatures: [SignaturePubkeyPair]

    // The first (payer) Transaction signature
    public var signature: Data? {
        signatures.first?.signature
    }

    /// The transaction fee payer
    public var feePayer: PublicKey?

    /// The instructions to atomically execute
    public var instructions: [TransactionInstruction] = []

    /// A recent transaction id. Must be populated by the caller
    public var recentBlockhash: Blockhash?

    /// Optional Nonce information. If populated, transaction will use a durable
    /// Nonce hash instead of a recentBlockhash. Must be populated by the caller
    public var nonceInfo: NonceInformation?

    public init(
        recentBlockhash: Blockhash? = nil,
        nonceInfo: NonceInformation? = nil,
        feePayer: PublicKey? = nil,
        signatures: [SignaturePubkeyPair] = []
    ) {
        self.recentBlockhash = recentBlockhash
        self.nonceInfo = nonceInfo
        self.feePayer = feePayer
        self.signatures = signatures
    }

    /// Parse a wire transaction into a Transaction object.
    public init(data: Data) throws {
        var data = data
        let signatureCount = Shortvec.decodeLength(data: &data)
        var signatures = [Data]()
        for index in 0..<signatureCount {
            let startIndex = index * signatureLength
            let endIndex = startIndex + signatureLength
            if endIndex < data.count {
                let signature = data[startIndex..<endIndex]
                signatures.append(signature)
            } else {
                throw Error.signatureHasInvalidLength
            }
        }

        let startIndex = signatureCount * signatureLength
        if startIndex < data.count {
            data = data[startIndex...]
        } else {
            throw Error.signatureHasInvalidLength
        }

        self.init(
            message: try Message(data: data),
            signatures: signatures)
    }

    /// Populate Transaction object from message and signatures
    public init(message: Message, signatures: [Data]) {
        self.recentBlockhash = message.recentBlockhash
        if message.header.numRequiredSignatures > 0 {
            self.feePayer = message.accountKeys.first
        }

        var signaturePubkeyPairs = [SignaturePubkeyPair]()
        for (index, signature) in signatures.enumerated() {
            let sigaturePublicKeyPair = SignaturePubkeyPair(
                signature: signature == defaultSignature ? nil : signature,
                publicKey: message.accountKeys[index])
            signaturePubkeyPairs.append(sigaturePublicKeyPair)
        }
        self.signatures = signaturePubkeyPairs

        var instructions = [TransactionInstruction]()
        message.instructions.forEach { instruction in
            let keys = instruction.accounts.map { account -> AccountMeta in
                let index = Int(account)
                let publicKey = message.accountKeys[index]

                let isSigner = self.signatures.contains(where: { $0.publicKey == publicKey }) ||
                    message.isAccountSigner(index: index)

                return AccountMeta(
                    publicKey: publicKey,
                    isSigner: isSigner,
                    isWritable: message.isAccountWritable(index: index))
            }

            instructions.append(
                TransactionInstruction(
                    keys: keys,
                    programId: message.accountKeys[Int(instruction.programIdIndex)],
                    data: Data(Base58.decode(instruction.data))))
        }
        self.instructions = instructions
    }

    /// Add one instruction to this Transaction
    public mutating func add(_ item: Transaction) {
        instructions.append(contentsOf: item.instructions)
    }

    /// Add instructions to this Transaction
    public mutating func add(_ items: [Transaction]) {
        items.forEach {
            instructions.append(contentsOf: $0.instructions)
        }
    }

    /// Add one instruction to this Transaction
    public mutating func add(_ item: TransactionInstruction) {
        instructions.append(item)
    }

    /// Add instructions to this Transaction
    public mutating func add(_ items: [TransactionInstruction]) {
        instructions.append(contentsOf: items)
    }

    /// Add instructions to this Transaction
    public mutating func add(keys: [AccountMeta], programId: PublicKey, data: Data? = nil) {
        let instruction = TransactionInstruction(keys: keys, programId: programId, data: data)
        instructions.append(instruction)
    }

    /// Compile transaction data
    @discardableResult
    public mutating func compileMessage() throws -> Message {
        if let nonceInfo = nonceInfo, instructions.first != nonceInfo.nonceInstruction {
            recentBlockhash = nonceInfo.nonce
            instructions.insert(nonceInfo.nonceInstruction, at: 0)
        }

        guard let recentBlockhash = recentBlockhash else {
            throw Error.recentBlockhashRequired
        }
        if instructions.count == 0 {
            debugPrint("warning: No instructions provided")
        }
        guard let feePayer = feePayer ?? signatures.first?.publicKey else {
            throw Error.feePayerRequired
        }

        // programIds & accountMetas
        var programIds = [PublicKey]()
        var accountMetas = [AccountMeta]()
        for instruction in instructions {
            accountMetas.append(contentsOf: instruction.keys)
            if !programIds.contains(instruction.programId) {
                programIds.append(instruction.programId)
            }
        }

        // Append programID account metas
        programIds.forEach {
            accountMetas.append(
                .init(publicKey: $0, isSigner: false, isWritable: false)
            )
        }

        // sort accountMetas, first by signer, then by writable
        accountMetas.sort { (x, y) -> Bool in
            if x.isSigner != y.isSigner { return x.isSigner }
            if x.isWritable != y.isWritable { return x.isWritable }
            return false
        }

        // Cull duplicate account metas
        var uniqueMetas: [AccountMeta] = []
        accountMetas.forEach { accountMeta in
            let pubkey = accountMeta.publicKey.base58
            let uniqueIndex = uniqueMetas.firstIndex { $0.publicKey.base58 == pubkey }
            if let uniqueIndex = uniqueIndex {
                uniqueMetas[uniqueIndex].isWritable = uniqueMetas[uniqueIndex].isWritable || accountMeta.isWritable
            } else {
                uniqueMetas.append(accountMeta)
            }
        }

        // Move fee payer to the front
        let feePayerIndex = uniqueMetas.firstIndex { $0.publicKey == feePayer }
        if let feePayerIndex = feePayerIndex {
            var payerMeta = uniqueMetas.remove(at: feePayerIndex)
            payerMeta.isSigner = true
            payerMeta.isWritable = true
            uniqueMetas.insert(payerMeta, at: 0)
        } else {
            uniqueMetas.insert(
                AccountMeta(
                    publicKey: feePayer,
                    isSigner: true,
                    isWritable: true),
                at: 0)
        }

        // Disallow unknown signers
        for signature in signatures {
            if let uniqueIndex = uniqueMetas.firstIndex(where: { $0.publicKey == signature.publicKey }) {
                uniqueMetas[uniqueIndex].isSigner = true
                debugPrint("Transaction references a signature that is unnecessary, only the fee payer and instruction signer accounts should sign a transaction. This behavior is deprecated and will throw an error in the next major version release.")
            } else {
                throw Error.unknownSigner(signature.publicKey.description)
            }
        }

        var numRequiredSignatures: UInt8 = 0
        var numReadonlySignedAccounts: UInt8 = 0
        var numReadonlyUnsignedAccounts: UInt8 = 0

        // Split out signing from non-signing keys and count header values
        var signedKeys = [PublicKey]()
        var unsignedKeys = [PublicKey]()
        uniqueMetas.forEach { accountMeta in
            if accountMeta.isSigner {
                signedKeys.append(accountMeta.publicKey)
                numRequiredSignatures += 1
                if accountMeta.isWritable == false {
                    numReadonlySignedAccounts += 1
                }
            } else {
                unsignedKeys.append(accountMeta.publicKey)
                if accountMeta.isWritable == false {
                    numReadonlyUnsignedAccounts += 1
                }
            }
        }

        let accountKeys = signedKeys + unsignedKeys
        let instructions: [CompiledInstruction] = instructions.map { instruction in
            CompiledInstruction(
                programIdIndex: UInt8(accountKeys.firstIndex(of: instruction.programId)!),
                accounts: instruction.keys.map { meta in
                    UInt8(accountKeys.firstIndex(of: meta.publicKey)!)
                },
                data: Base58.encode(instruction.data))
        }

        return Message(
            header: .init(
                numRequiredSignatures: numRequiredSignatures,
                numReadonlySignedAccounts: numReadonlySignedAccounts,
                numReadonlyUnsignedAccounts: numReadonlyUnsignedAccounts),
            accountKeys: accountKeys,
            recentBlockhash: recentBlockhash,
            instructions: instructions
        )
    }

    private mutating func compile() throws -> Message {
        let message = try compileMessage()
        let signedKeys = message.accountKeys[0..<Int(message.header.numRequiredSignatures)]
        if signatures.count == signedKeys.count {
            var isValid = true
            for (index, signature) in signatures.enumerated() {
                if signedKeys[index] != signature.publicKey {
                    isValid = false
                    break
                }
            }
            if isValid {
                return message
            }
        }
        signatures = signedKeys.map { SignaturePubkeyPair(signature: nil, publicKey: $0) }
        return message
    }

    /// Get a buffer of the Transaction data that need to be covered by signatures
    public mutating func serializeMessage() throws -> Data {
        try compile().serialize()
    }

    /// Get the estimated fee associated with a transaction
    // TODO: not finished
//    async getEstimatedFee(connection: Connection): Promise<number> {
//      return (await connection.getFeeForMessage(this.compileMessage())).value;
//    }

    /// Specify the public keys which will be used to sign the Transaction.
    /// The first signer will be used as the transaction fee payer account.
    ///
    /// Signatures can be added with either `partialSign` or `addSignature`
    ///
    /// @deprecated Deprecated. Only the fee payer needs to be
    /// specified and it can be set in the Transaction constructor or with the
    /// `feePayer` property.
    @available(*, deprecated, message: "Deprecated")
    public mutating func setSigners(_ signers: [PublicKey]) throws {
        guard signers.count > 0 else {
            throw Error.noSigners
        }

        var seen = Set<PublicKey>()
        signatures = signers.filter { publicKey in
            if seen.contains(publicKey) {
                return false
            } else {
                seen.insert(publicKey)
                return true
            }
        }.map { publicKey in
            SignaturePubkeyPair(signature: nil, publicKey: publicKey)
        }
    }

    /// Sign the Transaction with the specified signers. Multiple signatures may
    /// be applied to a Transaction. The first signature is considered "primary"
    /// and is used identify and confirm transactions.
    ///
    /// If the Transaction `feePayer` is not set, the first signer will be used
    /// as the transaction fee payer account.
    ///
    /// Transaction fields should not be modified after the first call to `sign`,
    /// as doing so may invalidate the signature and cause the Transaction to be
    /// rejected.
    ///
    /// The Transaction must be assigned a valid `recentBlockhash` before invoking this method
    public mutating func sign(_ signers: [Signer]) throws {
        guard signers.count > 0 else {
            throw Error.noSigners
        }

        // Dedupe signers
        var seen = Set<PublicKey>()
        var uniqueSigners = [Signer]()
        signers.forEach { signer in
            let publicKey = signer.publicKey
            if seen.contains(publicKey) {
                return
            } else {
                seen.insert(publicKey)
                uniqueSigners.append(signer)
            }
        }

        signatures = uniqueSigners.map { SignaturePubkeyPair(signature: nil, publicKey: $0.publicKey) }

        let message = try compile()
        try partialSign(message: message, signers: uniqueSigners)
        _ = try verifySignatures(signData: message.serialize(), requireAllSignatures: true)
    }

    public mutating func sign(_ signers: [Ed25519Keypair]) throws {
        try self.sign(try signers.map { Signer(publicKey: try PublicKey($0.publicKey), secretKey: $0.secretKey) })
    }

    public mutating func sign(_ signers: [Keypair]) throws {
        try self.sign(signers.map { $0.keypair })
    }

    public mutating func sign(_ signer: Keypair) throws {
        try self.sign([signer.keypair])
    }

    /// Partially sign a transaction with the specified accounts. All accounts must
    /// correspond to either the fee payer or a signer account in the transaction
    /// instructions.
    ///
    /// All the caveats from the `sign` method apply to `partialSign`
    public mutating func partialSign(signers: [Signer]) throws {
        guard signers.count > 0 else {
            throw Error.noSigners
        }

        // Dedupe signers
        var seen = Set<PublicKey>()
        var uniqueSigners = [Signer]()
        signers.forEach { signer in
            let publicKey = signer.publicKey
            if seen.contains(publicKey) {
                return
            } else {
                seen.insert(publicKey)
                uniqueSigners.append(signer)
            }
        }

        let message = try compile()
        try partialSign(message: message, signers: signers)
    }

    public mutating func partialSign(signers: [Keypair]) throws {
        try partialSign(signers: try signers.map {
            Signer(publicKey: try $0.publicKey, secretKey: $0.secretKey)
        })
    }

    private mutating func partialSign(message: Message, signers: [Signer]) throws {
        let signData = message.serialize()
        try signers.forEach { signer in
            let signature = try NaclSign.signDetached(message: signData, secretKey: signer.secretKey)
            try _addSignature(publicKey: signer.publicKey, signature: signature)
        }
    }

    public mutating func partialSign(message: Message, signers: [Keypair]) throws {
        try partialSign(message: message, signers: try signers.map {
            Signer(publicKey: try $0.publicKey, secretKey: $0.secretKey)
        })
    }

    /// Add an externally created signature to a transaction. The public key
    /// must correspond to either the fee payer or a signer account in the transaction
    /// instructions.
    public mutating func addSignature(publicKey: PublicKey, signature: Data) throws {
        _ = try compile() // Ensure signatures array is populated
        try _addSignature(publicKey: publicKey, signature: signature)
    }

    private mutating func _addSignature(publicKey: PublicKey, signature: Data) throws {
        guard signature.count == signatureLength else {
            throw Error.signatureHasInvalidLength
        }

        if let index = signatures.firstIndex(where: { $0.publicKey == publicKey }) {
            signatures[index].signature = signature
        } else {
            throw Error.unknownSigner(publicKey.description)
        }
    }

    /// Verify signatures of a complete, signed Transaction
    public mutating func verifySignatures() throws -> Bool {
        try verifySignatures(signData: try serializeMessage(), requireAllSignatures: true)
    }

    private func verifySignatures(signData: Data, requireAllSignatures: Bool) throws -> Bool {
        for signature in signatures {
            let publicKey = signature.publicKey
            if let signature = signature.signature {
                if try NaclSign.signDetachedVerify(message: signData, sig: signature, publicKey: publicKey.data) == false {
                    return false
                }
            } else {
                if requireAllSignatures {
                    return false
                }
            }
        }
        return true
    }

    public mutating func serialize(config: SerializeConfig = SerializeConfig()) throws -> Data {
        let signData = try serializeMessage()

        if config.verifySignatures,
           try verifySignatures(signData: signData, requireAllSignatures: config.requireAllSignatures) == false {
            throw Error.signatureVerificationFailed
        }

        return try serialize(signData: signData)
    }

    private func serialize(signData: Data) throws -> Data {
        let signatureCount = Shortvec.encodeLength(signatures.count)
        let transactionLength = signatureCount.count + signatures.count * signatureLength + signData.count
        var wireTransaction = Data(capacity: transactionLength)
        guard signatures.count < 256 else {
            throw Error.invalidSignatureCount
        }
        wireTransaction.append(signatureCount)
        try signatures.forEach { signature in
            if let signature = signature.signature {
                guard signature.count == signatureLength else {
                    throw Error.signatureHasInvalidLength
                }
                wireTransaction.append(signature)
            }
        }
        wireTransaction.append(signData)
        guard wireTransaction.count <= packetDataSize else {
            throw Error.transactionTooLarge(size: wireTransaction.count, max: packetDataSize)
        }

        return wireTransaction
    }

}

// MARK: - Error
extension Transaction {

    public enum Error: Swift.Error, Equatable {
        case recentBlockhashRequired
        case feePayerRequired
        case unknownSigner(String)
        case noSigners
        case invalidSignatureCount
        case signatureHasInvalidLength
        case signatureVerificationFailed
        case transactionTooLarge(size: Int, max: Int)
    }
}
