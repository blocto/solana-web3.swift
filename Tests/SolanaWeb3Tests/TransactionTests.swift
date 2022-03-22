//
//  TransactionTests.swift
//  SolanaWeb3
//
//  Created by Scott on 2022/3/14.
//

import XCTest
import SolanaWeb3

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

        try transaction.sign([payer])

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
    }
//    it('partialSign', () => {
//        const account1 = Keypair.generate();
//        const account2 = Keypair.generate();
//        const recentBlockhash = account1.publicKey.toBase58(); // Fake recentBlockhash
//        const transfer = SystemProgram.transfer({
//          fromPubkey: account1.publicKey,
//          toPubkey: account2.publicKey,
//          lamports: 123,
//        });
//
//        const transaction = new Transaction({recentBlockhash}).add(transfer);
//        transaction.sign(account1, account2);
//
//        const partialTransaction = new Transaction({recentBlockhash}).add(transfer);
//        partialTransaction.setSigners(account1.publicKey, account2.publicKey);
//        expect(partialTransaction.signatures[0].signature).to.be.null;
//        expect(partialTransaction.signatures[1].signature).to.be.null;
//
//        partialTransaction.partialSign(account1);
//        expect(partialTransaction.signatures[0].signature).not.to.be.null;
//        expect(partialTransaction.signatures[1].signature).to.be.null;
//
//        expect(() => partialTransaction.serialize()).to.throw();
//        expect(() =>
//          partialTransaction.serialize({requireAllSignatures: false}),
//        ).not.to.throw();
//
//        partialTransaction.partialSign(account2);
//
//        expect(partialTransaction.signatures[0].signature).not.to.be.null;
//        expect(partialTransaction.signatures[1].signature).not.to.be.null;
//
//        expect(() => partialTransaction.serialize()).not.to.throw();
//
//        expect(partialTransaction).to.eql(transaction);
//
//        invariant(partialTransaction.signatures[0].signature);
//        partialTransaction.signatures[0].signature[0] = 0;
//        expect(() =>
//          partialTransaction.serialize({requireAllSignatures: false}),
//        ).to.throw();
//        expect(() =>
//          partialTransaction.serialize({
//            verifySignatures: false,
//            requireAllSignatures: false,
//          }),
//        ).not.to.throw();
//      });

}
