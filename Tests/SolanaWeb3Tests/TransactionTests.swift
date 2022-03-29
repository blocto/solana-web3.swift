//
//  TransactionTests.swift
//  SolanaWeb3
//
//  Created by Scott on 2022/3/14.
//

import XCTest
import SolanaWeb3
import CryptoSwift

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

    // TODO: not finished
//    it('getEstimatedFee', async () => {
//    const connection = new Connection('https://api.testnet.solana.com');
//    const accountFrom = Keypair.generate();
//    const accountTo = Keypair.generate();
//
//    const {blockhash} = await helpers.latestBlockhash({connection});
//
//    const transaction = new Transaction({
//      feePayer: accountFrom.publicKey,
//      recentBlockhash: blockhash,
//    }).add(
//      SystemProgram.transfer({
//        fromPubkey: accountFrom.publicKey,
//        toPubkey: accountTo.publicKey,
//        lamports: 10,
//      }),
//    );
//
//    const fee = await transaction.getEstimatedFee(connection);
//    expect(fee).to.eq(5000);
//  });

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

}
