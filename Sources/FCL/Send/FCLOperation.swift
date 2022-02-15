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
    func getAccount(address: String) -> Future<Flow.Account?, Error> {
        return flow.accessAPI
            .getAccountAtLatestBlock(address: Flow.Address(hex: address))
            .toFuture()
    }

    func getBlock(blockId: String) -> Future<Flow.Block?, Error> {
        return flow.accessAPI
            .getBlockById(id: Flow.ID(hex: blockId))
            .toFuture()
    }

    func getLastestBlock(sealed: Bool = true) -> Future<Flow.Block, Error> {
        return flow.accessAPI
            .getLatestBlock(sealed: sealed)
            .toFuture()
    }

    func getBlockHeader(blockId: String) -> Future<Flow.BlockHeader?, Error> {
        return flow.accessAPI
            .getBlockHeaderById(id: Flow.ID(hex: blockId))
            .toFuture()
    }

    func getTransactionStatus(transactionId: String) -> Future<Flow.TransactionResult, Error> {
        return flow.accessAPI
            .getTransactionResultById(id: Flow.ID(hex: transactionId))
            .toFuture()
    }

    func getTransaction(transactionId: String) -> Future<Flow.Transaction?, Error> {
        return flow.accessAPI
            .getTransactionById(id: Flow.ID(hex: transactionId))
            .toFuture()
    }
}
