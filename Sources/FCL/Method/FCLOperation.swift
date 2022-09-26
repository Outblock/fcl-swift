//
//  File.swift
//
//
//  Created by lmcmz on 3/11/21.
//

import Combine
import Flow
import Foundation

public extension FCL {
    func getAccount(address: String) async throws -> Flow.Account {
        return try await flow.accessAPI
            .getAccountAtLatestBlock(address: Flow.Address(hex: address))
    }

    func getBlock(blockId: String) async throws -> Flow.Block {
        return try await flow.accessAPI
            .getBlockById(id: Flow.ID(hex: blockId))
    }

    func getLastestBlock(sealed: Bool = true) async throws -> Flow.Block {
        return try await flow.accessAPI
            .getLatestBlock(sealed: sealed)
    }

    func getBlockHeader(blockId: String) async throws -> Flow.BlockHeader {
        return try await flow.accessAPI
            .getBlockHeaderById(id: Flow.ID(hex: blockId))
    }

    func getTransactionStatus(transactionId: String) async throws -> Flow.TransactionResult {
        return try await flow.accessAPI
            .getTransactionResultById(id: Flow.ID(hex: transactionId))
    }

    func getTransaction(transactionId: String) async throws -> Flow.Transaction {
        return try await flow.accessAPI
            .getTransactionById(id: Flow.ID(hex: transactionId))
    }
}
