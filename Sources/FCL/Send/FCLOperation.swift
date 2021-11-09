//
//  File.swift
//
//
//  Created by lmcmz on 3/11/21.
//

import Combine
import Flow
import Foundation

extension FCL {
    public func getAccount(address: String) -> Future<Flow.Account?, Error> {
        return flow.accessAPI
            .getAccountAtLatestBlock(address: Flow.Address(hex: address))
            .toFuture()
    }

    public func getBlock(blockId: String) -> Future<Flow.Block?, Error> {
        return flow.accessAPI
            .getBlockById(id: Flow.ID(hex: blockId))
            .toFuture()
    }

    public func getLastestBlock(sealed: Bool = true) -> Future<Flow.Block, Error> {
        return flow.accessAPI
            .getLatestBlock(sealed: sealed)
            .toFuture()
    }

    public func getBlockHeader(blockId: String) -> Future<Flow.BlockHeader?, Error> {
        return flow.accessAPI
            .getBlockHeaderById(id: Flow.ID(hex: blockId))
            .toFuture()
    }

    public func getTransactionStatus(transactionId: String) -> Future<Flow.TransactionResult, Error> {
        return flow.accessAPI
            .getTransactionResultById(id: Flow.ID(hex: transactionId))
            .toFuture()
    }

    public func getTransaction(transactionId: String) -> Future<Flow.Transaction?, Error> {
        return flow.accessAPI
            .getTransactionById(id: Flow.ID(hex: transactionId))
            .toFuture()
    }
}
