//
//  TransactionTests.swift
//  SolanaWeb3
//
//  Created by Scott on 2022/3/14.
//

import XCTest
import SolanaWeb3
import CryptoSwift
import TweetNacl
import Alamofire
import Mocker

final class TransactionTests: XCTestCase {

    func testCompileMessageAccountKeysAreOrdered() throws {
        let payer = try Keypair()
        let account2 = try Keypair()
        let account3 = try Keypair()
        let recentBlockhash = try Keypair().publicKey.base58
        let programId = try Keypair().publicKey

        var transaction = Transaction(recentBlockhash: recentBlockhash)
        transaction.add(
            keys: [
                AccountMeta(publicKey: try account3.publicKey, isSigner: true, isWritable: false),
                AccountMeta(publicKey: try payer.publicKey, isSigner: true, isWritable: true),
                AccountMeta(publicKey: try account2.publicKey, isSigner: true, isWritable: true)
            ],
            programId: programId)

        try transaction.setSigners([
            try payer.publicKey,
            try account2.publicKey,
            try account3.publicKey
        ])

        let message = try transaction.compileMessage()
        XCTAssertEqual(message.accountKeys[0], try payer.publicKey)
        XCTAssertEqual(message.accountKeys[1], try account2.publicKey)
        XCTAssertEqual(message.accountKeys[2], try account3.publicKey)
    }

    func testCompileMessageThatPayerIsFirstAccountMeta() throws {
        let payer = try Keypair()
        let other = try Keypair()
        let recentBlockhash = try Keypair().publicKey.base58
        let programId = try Keypair().publicKey
        var transaction = Transaction(recentBlockhash: recentBlockhash)
        transaction.add(
            keys: [
                AccountMeta(publicKey: try other.publicKey, isSigner: true, isWritable: true),
                AccountMeta(publicKey: try payer.publicKey, isSigner: true, isWritable: true)
            ],
            programId: programId)

        try transaction.sign([payer, other])

        let message = try transaction.compileMessage()
        XCTAssertEqual(message.accountKeys[0], try payer.publicKey)
        XCTAssertEqual(message.accountKeys[1], try other.publicKey)
        XCTAssertEqual(message.header.numRequiredSignatures, 2)
        XCTAssertEqual(message.header.numReadonlySignedAccounts, 0)
        XCTAssertEqual(message.header.numReadonlyUnsignedAccounts, 1)
    }

    func testCompileMessageValidation() throws {
        let payer = try Keypair()
        let recentBlockhash = try Keypair().publicKey.base58

        var transaction = Transaction()
        var thrownError: Error?
        XCTAssertThrowsError(try transaction.compileMessage()) { error in
            thrownError = error
        }
        XCTAssertEqual(thrownError as? Transaction.Error, .recentBlockhashRequired)

        transaction.recentBlockhash = recentBlockhash

        XCTAssertThrowsError(try transaction.compileMessage()) { error in
            thrownError = error
        }
        XCTAssertEqual(thrownError as? Transaction.Error, .feePayerRequired)

        let randomPublicKey = try Keypair().publicKey
        try transaction.setSigners([try payer.publicKey, randomPublicKey])

        XCTAssertThrowsError(try transaction.compileMessage()) { error in
            thrownError = error
        }
        XCTAssertEqual(thrownError as? Transaction.Error, .unknownSigner(randomPublicKey.description))

        // Expect compile to succeed with implicit fee payer from signers
        try transaction.setSigners([try payer.publicKey])
        try transaction.compileMessage()

        // Expect compile to succeed with fee payer and no signers
        transaction.signatures = []
        transaction.feePayer = try payer.publicKey
        try transaction.compileMessage()
    }

    func testCompileMessageThatPayerIsWritable() throws {
        let payer = try Keypair()
        let recentBlockhash = try Keypair().publicKey.base58
        let programId = try Keypair().publicKey
        var transaction = Transaction(recentBlockhash: recentBlockhash)
        transaction.add(
            keys: [
                AccountMeta(publicKey: try payer.publicKey, isSigner: true, isWritable: false)
            ],
            programId: programId)

        try transaction.sign(payer)

        let message = try transaction.compileMessage()
        XCTAssertEqual(message.accountKeys[0], try payer.publicKey)
        XCTAssertEqual(message.header.numRequiredSignatures, 1)
        XCTAssertEqual(message.header.numReadonlySignedAccounts, 0)
        XCTAssertEqual(message.header.numReadonlyUnsignedAccounts, 1)
    }

    func testGetEstimatedFee() throws {
        // Mock api response
        let configuration = URLSessionConfiguration.af.default
        configuration.protocolClasses = [MockingURLProtocol.self] + (configuration.protocolClasses ?? [])
        let session = Session(configuration: configuration)

        let endpoint = URL(string: "https://api.testnet.solana.com")!
        let response = """
{"jsonrpc":"2.0","result":{"context":{"slot":0},"value":5000},"id":"91E42C42-00D1-4FF2-80ED-2609E6890961"}
"""
        let data = response.data(using: .utf8)!
        let mock = Mock(url: endpoint, dataType: .json, statusCode: 200, data: [.post: data])
        mock.register()

        let connection = Connection(endpointURL: endpoint, session: session)
        let accountFrom = try Keypair()
        let accountTo = try Keypair()

        var transaction = Transaction(
            recentBlockhash: "Blockhash",
            feePayer: try accountFrom.publicKey)
        transaction.add(try SystemProgram.transfer(
            fromPublicKey: try accountFrom.publicKey,
            toPublicKey: try accountTo.publicKey,
            lamports: 10))

        var result: Result<UInt64, Error>?
        let exp = expectation(description: "wait for api response")
        transaction.getEstimatedFee(connection: connection) { localResult in
            debugPrint("Scott \(localResult)")
            result = localResult
            exp.fulfill()
        }
        wait(for: [exp], timeout: 0.1)
        XCTAssertEqual(try result?.get(), 5000)
    }

    func testPartialSign() throws {
        let account1 = try Keypair()
        let account2 = try Keypair()
        let recentBlockhash = try account1.publicKey.base58 // Fake recentBlockhash
        let transfer = try SystemProgram.transfer(
            fromPublicKey: try account1.publicKey,
            toPublicKey: try account2.publicKey,
            lamports: 123)

        var transaction = Transaction(recentBlockhash: recentBlockhash)
        transaction.add(transfer)
        try transaction.sign([account1, account2])

        var partialTransaction = Transaction(recentBlockhash: recentBlockhash)
        partialTransaction.add(transfer)
        try partialTransaction.setSigners([try account1.publicKey, try account2.publicKey])
        XCTAssertNil(partialTransaction.signatures[0].signature)
        XCTAssertNil(partialTransaction.signatures[1].signature)

        try partialTransaction.partialSign(signers: [account1])
        XCTAssertNotNil(partialTransaction.signatures[0].signature)
        XCTAssertNil(partialTransaction.signatures[1].signature)

        XCTAssertThrowsError(try partialTransaction.serialize())
        XCTAssertNoThrow(try partialTransaction.serialize(config: .init(requireAllSignatures: false)))

        try partialTransaction.partialSign(signers: [account2])

        XCTAssertNotNil(partialTransaction.signatures[0].signature)
        XCTAssertNotNil(partialTransaction.signatures[1].signature)

        XCTAssertNoThrow(try partialTransaction.serialize())

        XCTAssertEqual(partialTransaction, transaction)

        XCTAssertTrue(partialTransaction.signatures[0].signature != nil)

        var signature = partialTransaction.signatures[0].signature
        signature?[0] = 0
        let keypair = SignaturePubkeyPair(
            signature: signature,
            publicKey: partialTransaction.signatures[0].publicKey)
        partialTransaction.signatures[0] = keypair
        XCTAssertThrowsError(try partialTransaction.serialize(
            config: .init(requireAllSignatures: false)))
        XCTAssertNoThrow(try partialTransaction.serialize(
            config: .init(requireAllSignatures: false, verifySignatures: false)))
    }

    func testDedupeSetSigners() throws {
        let payer = try Keypair()
        let duplicate1 = payer
        let duplicate2 = payer
        let recentBlockhash = try Keypair().publicKey.base58
        let programId = try Keypair().publicKey

        var transaction = Transaction(recentBlockhash: recentBlockhash)
        transaction.add(
            keys: [
                AccountMeta(publicKey: try duplicate1.publicKey, isSigner: true, isWritable: true),
                AccountMeta(publicKey: try payer.publicKey, isSigner: false, isWritable: true),
                AccountMeta(publicKey: try duplicate2.publicKey, isSigner: true, isWritable: false)
            ],
            programId: programId)

        try transaction.setSigners([
            try payer.publicKey,
            try duplicate1.publicKey,
            try duplicate2.publicKey
        ])

        XCTAssertEqual(transaction.signatures.count, 1)
        XCTAssertEqual(transaction.signatures[0].publicKey, try payer.publicKey)

        let message = try transaction.compileMessage()
        XCTAssertEqual(message.accountKeys[0], try payer.publicKey)
        XCTAssertEqual(message.header.numRequiredSignatures, 1)
        XCTAssertEqual(message.header.numReadonlySignedAccounts, 0)
        XCTAssertEqual(message.header.numReadonlyUnsignedAccounts, 1)
    }

    func testDedupeSign() throws {
        let payer = try Keypair()
        let duplicate1 = payer
        let duplicate2 = payer
        let recentBlockhash = try Keypair().publicKey.base58
        let programId = try Keypair().publicKey

        var transaction = Transaction(recentBlockhash: recentBlockhash)
        transaction.add(
            keys: [
                AccountMeta(publicKey: try duplicate1.publicKey, isSigner: true, isWritable: true),
                AccountMeta(publicKey: try payer.publicKey, isSigner: false, isWritable: true),
                AccountMeta(publicKey: try duplicate2.publicKey, isSigner: true, isWritable: false)
            ],
            programId: programId)

        try transaction.sign([payer, duplicate1, duplicate2])

        XCTAssertEqual(transaction.signatures.count, 1)
        XCTAssertEqual(transaction.signatures[0].publicKey, try payer.publicKey)

        let message = try transaction.compileMessage()
        XCTAssertEqual(message.accountKeys[0], try payer.publicKey)
        XCTAssertEqual(message.header.numRequiredSignatures, 1)
        XCTAssertEqual(message.header.numReadonlySignedAccounts, 0)
        XCTAssertEqual(message.header.numReadonlyUnsignedAccounts, 1)
    }

    func testTransferSignatures() throws {
        let account1 = try Keypair()
        let account2 = try Keypair()
        let recentBlockhash = try Keypair().publicKey.base58
        let transfer1 = try SystemProgram.transfer(
            fromPublicKey: try account1.publicKey,
            toPublicKey: try account2.publicKey,
            lamports: 123)
        let transfer2 = try SystemProgram.transfer(
            fromPublicKey: try account2.publicKey,
            toPublicKey: try account1.publicKey,
            lamports: 123)

        var orgTransaction = Transaction(recentBlockhash: recentBlockhash)
        orgTransaction.add([transfer1, transfer2])
        try orgTransaction.sign([account1, account2])

        var newTransaction = Transaction(
            recentBlockhash: orgTransaction.recentBlockhash,
            signatures: orgTransaction.signatures)
        newTransaction.add([transfer1, transfer2])

        XCTAssertEqual(newTransaction, orgTransaction)
    }

    func testDedupSignatures() throws {
        let account1 = try Keypair()
        let account2 = try Keypair()
        let recentBlockhash = try account1.publicKey.base58 // Fake recentBlockhash
        let transfer1 = try SystemProgram.transfer(
            fromPublicKey: try account1.publicKey,
            toPublicKey: try account2.publicKey,
            lamports: 123)
        let transfer2 = try SystemProgram.transfer(
            fromPublicKey: try account1.publicKey,
            toPublicKey: try account2.publicKey,
            lamports: 123)

        var orgTransaction = Transaction(recentBlockhash: recentBlockhash)
        orgTransaction.add([transfer1, transfer2])

        try orgTransaction.sign(account1)
    }

    func testUseNonce() throws {
        let account1 = try Keypair()
        let account2 = try Keypair()
        let nonceAccount = try Keypair()
        let nonce = try account2.publicKey.base58
        let nonceInfo = NonceInformation(
            nonce: nonce,
            nonceInstruction: try SystemProgram.nonceAdvance(
                noncePublicKey: try nonceAccount.publicKey,
                authorizedPublicKey: try account1.publicKey))

        var transferTransaction = Transaction(nonceInfo: nonceInfo)
        transferTransaction.add(try SystemProgram.transfer(
            fromPublicKey: try account1.publicKey,
            toPublicKey: try account2.publicKey,
            lamports: 123))
        try transferTransaction.sign(account1)

        var expectedData = Data()
        expectedData.append(contentsOf: [4, 0, 0, 0])

        XCTAssertEqual(transferTransaction.instructions.count, 2)
        XCTAssertEqual(transferTransaction.instructions[0].programId, SystemProgram.programId)
        XCTAssertEqual(transferTransaction.instructions[0].data, expectedData)
        XCTAssertEqual(transferTransaction.recentBlockhash, nonce)

        let stakeAccount = try Keypair()
        let voteAccount = try Keypair()
        var stakeTransaction = Transaction(nonceInfo: nonceInfo)
        stakeTransaction.add(try StakeProgram.delegate(
            stakePublicKey: try stakeAccount.publicKey,
            authorizedPublicKey: try account1.publicKey,
            votePublicKey: try voteAccount.publicKey))
        try stakeTransaction.sign(account1)

        XCTAssertEqual(stakeTransaction.instructions.count, 2)
        XCTAssertEqual(stakeTransaction.instructions[0].programId, SystemProgram.programId)
        XCTAssertEqual(stakeTransaction.instructions[0].data, expectedData)
        XCTAssertEqual(stakeTransaction.recentBlockhash, nonce)
    }

    func testParseWireFormatAndSerialize() throws {
        let sender = try Keypair(seed: Data(repeating: 8, count: 32)) // Arbitrary known account
        let recentBlockhash = "EETubP5AKHgjPAhzPAFcb8BAY1hMH639CWCFTqi3hq1k" // Arbitrary known recentBlockhash
        let recipient = try PublicKey("J3dxNj7nDRRqRRXuEMynDG57DkZK4jYRuv3Garmb1i99") // Arbitrary known public key
        let transfer = try SystemProgram.transfer(
            fromPublicKey: try sender.publicKey,
            toPublicKey: recipient,
            lamports: 49)
        var expectedTransaction = Transaction(recentBlockhash: recentBlockhash, feePayer: try sender.publicKey)
        expectedTransaction.add(transfer)
        try expectedTransaction.sign(sender)

        let wireTransaction = Data(base64Encoded: "AVuErQHaXv0SG0/PchunfxHKt8wMRfMZzqV0tkC5qO6owYxWU2v871AoWywGoFQr4z+q/7mE8lIufNl/kxj+nQ0BAAEDE5j2LG0aRXxRumpLXz29L2n8qTIWIY3ImX5Ba9F9k8r9Q5/Mtmcn8onFxt47xKj+XdXXd3C8j/FcPu7csUrz/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAxJrndgN4IFTxep3s6kO0ROug7bEsbx0xxuDkqEvwUusBAgIAAQwCAAAAMQAAAAAAAAA=")!
        let tx = try Transaction(data: wireTransaction)

        XCTAssertEqual(tx, expectedTransaction)
        XCTAssertEqual(tx.signatures[0].signature?.bytes, expectedTransaction.signatures[0].signature?.bytes)
        XCTAssertEqual(tx.feePayer, expectedTransaction.feePayer)
        XCTAssertEqual(tx.instructions, expectedTransaction.instructions)
        XCTAssertEqual(tx.recentBlockhash, expectedTransaction.recentBlockhash)
        XCTAssertEqual(wireTransaction, try expectedTransaction.serialize())
    }

    func testPopulateTransaction() throws {
        let recentBlockhash = try PublicKey(1).description
        let message = try Message(
            header: MessageHeader(
                numRequiredSignatures: 2,
                numReadonlySignedAccounts: 0,
                numReadonlyUnsignedAccounts: 3),
            accountKeys: [
                try PublicKey(1).description,
                try PublicKey(2).description,
                try PublicKey(3).description,
                try PublicKey(4).description,
                try PublicKey(5).description
            ],
            recentBlockhash: recentBlockhash,
            instructions: [
                CompiledInstruction(
                    programIdIndex: 4,
                    accounts: [1, 2, 3],
                    data: Base58.encode(Data(repeating: 9, count: 5)))
            ])

        let signatures = [
            Base58.encode(Data(repeating: 1, count: 64)),
            Base58.encode(Data(repeating: 2, count: 64))
        ]

        let transaction = Transaction(message: message, signatures: signatures)
        XCTAssertEqual(transaction.instructions.count, 1)
        XCTAssertEqual(transaction.signatures.count, 2)
        XCTAssertEqual(transaction.recentBlockhash, recentBlockhash)
    }

    func testSerializeUnsignedTransaction() throws {
        let sender = try Keypair(seed: Data(repeating: 8, count: 32)) // Arbitrary known account
        let recentBlockhash = "EETubP5AKHgjPAhzPAFcb8BAY1hMH639CWCFTqi3hq1k" // Arbitrary known recentBlockhash
        let recipient = try PublicKey("J3dxNj7nDRRqRRXuEMynDG57DkZK4jYRuv3Garmb1i99") // Arbitrary known public key
        let transfer = try SystemProgram.transfer(
            fromPublicKey: try sender.publicKey,
            toPublicKey: recipient,
            lamports: 49)
        var expectedTransaction = Transaction(recentBlockhash: recentBlockhash)
        expectedTransaction.add(transfer)

        // Empty signature array fails.
        XCTAssertEqual(expectedTransaction.signatures.count, 0)
        XCTAssertThrowsError(try expectedTransaction.serialize())
        XCTAssertThrowsError(try expectedTransaction.serialize()) { error in
            XCTAssertEqual(error as? Transaction.Error, .feePayerRequired)
        }
        XCTAssertThrowsError(try expectedTransaction.serialize(config: .init(verifySignatures: true))) { error in
            XCTAssertEqual(error as? Transaction.Error, .feePayerRequired)
        }
        XCTAssertThrowsError(try expectedTransaction.serializeMessage()) { error in
            XCTAssertEqual(error as? Transaction.Error, .feePayerRequired)
        }

        expectedTransaction.feePayer = try sender.publicKey

        // Transactions with missing signatures will fail sigverify.
        XCTAssertThrowsError(try expectedTransaction.serialize()) { error in
            XCTAssertEqual(error as? Transaction.Error, .signatureVerificationFailed)
        }

        // Serializing without signatures is allowed if sigverify disabled.
        try expectedTransaction.serialize(config: .init(verifySignatures: false))

        // Serializing the message is allowed when signature array has null signatures
        try expectedTransaction.serializeMessage()

        expectedTransaction.feePayer = nil
        try expectedTransaction.setSigners([try sender.publicKey])
        XCTAssertEqual(expectedTransaction.signatures.count, 1)

        // Transactions with missing signatures will fail sigverify.
        XCTAssertThrowsError(try expectedTransaction.serialize()) { error in
            XCTAssertEqual(error as? Transaction.Error, .signatureVerificationFailed)
        }

        // Serializing without signatures is allowed if sigverify disabled.
        try expectedTransaction.serialize(config: .init(verifySignatures: false))

        // Serializing the message is allowed when signature array has null signatures
        try expectedTransaction.serializeMessage()

        let expectedSerializationWithNoSignatures = Data(
            base64Encoded: "AQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" +
            "AAAAAAAAAAAAAAAAAAABAAEDE5j2LG0aRXxRumpLXz29L2n8qTIWIY3ImX5Ba9F9k8r9" +
            "Q5/Mtmcn8onFxt47xKj+XdXXd3C8j/FcPu7csUrz/AAAAAAAAAAAAAAAAAAAAAAAAAAA" +
            "AAAAAAAAAAAAAAAAxJrndgN4IFTxep3s6kO0ROug7bEsbx0xxuDkqEvwUusBAgIAAQwC" +
            "AAAAMQAAAAAAAAA=")!
        XCTAssertEqual(
            try expectedTransaction.serialize(config: .init(requireAllSignatures: false)),
            expectedSerializationWithNoSignatures)

        // Properly signed transaction succeeds
        try expectedTransaction.partialSign(signers: [sender])
        XCTAssertEqual(expectedTransaction.signatures.count, 1)
        let expectedSerialization = Data(
            base64Encoded: "AVuErQHaXv0SG0/PchunfxHKt8wMRfMZzqV0tkC5qO6owYxWU2v871AoWywGoFQr4z+q/7mE8lIufNl/" +
            "kxj+nQ0BAAEDE5j2LG0aRXxRumpLXz29L2n8qTIWIY3ImX5Ba9F9k8r9Q5/Mtmcn8onFxt47xKj+XdXX" +
            "d3C8j/FcPu7csUrz/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAxJrndgN4IFTxep3s6kO0" +
            "ROug7bEsbx0xxuDkqEvwUusBAgIAAQwCAAAAMQAAAAAAAAA=")
        XCTAssertEqual(try expectedTransaction.serialize(), expectedSerialization)
        XCTAssertEqual(expectedTransaction.signatures.count, 1)
    }

    func testExternallySignedStakeDelegate() throws {
        let authority = try Keypair(seed: Data(repeating: 1, count: 32))
        let stake = try PublicKey(2)
        let recentBlockhash = try PublicKey(3).serialize()
        let vote = try PublicKey(4)
        var tx = try StakeProgram.delegate(
            stakePublicKey: stake,
            authorizedPublicKey: try authority.publicKey,
            votePublicKey: vote)
        let from = authority
        tx.recentBlockhash = Base58.encode(recentBlockhash)
        tx.feePayer = try from.publicKey
        let txData = try tx.serializeMessage()
        let signature = try NaclSign.signDetached(message: txData, secretKey: from.secretKey)
        try tx.addSignature(publicKey: try from.publicKey, signature: signature)
        XCTAssertEqual(try tx.verifySignatures(), true)
    }

    func testCanSerializeDeserializeAndReserializeWithAPartialSigner() throws {
        let signer = try Keypair(seed: Data(repeating: 1, count: 32))
        let acc0Writable = try Keypair(seed: Data(repeating: 2, count: 32))
        let acc1Writable = try Keypair(seed: Data(repeating: 3, count: 32))
        let acc2Writable = try Keypair(seed: Data(repeating: 4, count: 32))
        let programId = try Keypair(seed: Data(repeating: 5, count: 32))

        var t0 = Transaction(
            recentBlockhash: "HZaTsZuhN1aaz9WuuimCFMyH7wJ5xiyMUHFCnZSMyguH",
            feePayer: try signer.publicKey)
        t0.add(TransactionInstruction(
            keys: [
                AccountMeta(publicKey: try signer.publicKey, isSigner: true, isWritable: true),
                AccountMeta(publicKey: try acc0Writable.publicKey, isSigner: false, isWritable: true)
            ],
            programId: try programId.publicKey))
        t0.add(TransactionInstruction(
            keys: [
                AccountMeta(publicKey: try acc1Writable.publicKey, isSigner: false, isWritable: false)
            ],
            programId: try programId.publicKey))
        t0.add(TransactionInstruction(
            keys: [
                AccountMeta(publicKey: try acc2Writable.publicKey, isSigner: false, isWritable: true)
            ],
            programId: try programId.publicKey))
        t0.add(TransactionInstruction(
            keys: [
                AccountMeta(publicKey: try signer.publicKey, isSigner: true, isWritable: true),
                AccountMeta(publicKey: try acc0Writable.publicKey, isSigner: false, isWritable: false),
                AccountMeta(publicKey: try acc2Writable.publicKey, isSigner: false, isWritable: false),
                AccountMeta(publicKey: try acc1Writable.publicKey, isSigner: false, isWritable: true)
            ],
            programId: try programId.publicKey))
        try t0.partialSign(signers: [signer])
        var t1 = try Transaction(data: try t0.serialize())
        try t1.serialize()
    }

}
