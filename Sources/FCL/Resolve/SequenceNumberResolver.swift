//
//  File.swift
//  File
//
//  Created by lmcmz on 1/11/21.
//

import Combine
import Flow
import Foundation

final class SequenceNumberResolver: Resolver {
    func resolve(ix: inout Interaction) async throws -> Interaction {
        guard ix.tag == .transaction else {
            return ix
        }

        guard let proposer = ix.proposer,
              let account = ix.accounts[proposer],
              let address = account.addr,
              let keyID = account.keyID
        else {
            throw FCLError.generic
        }

        let flowAddress = Flow.Address(hex: address)

        if account.sequenceNum == nil {
            let accountData = try await flow.accessAPI.getAccountAtLatestBlock(address: flowAddress)
            ix.accounts[proposer]?.sequenceNum = Int(accountData.keys[keyID].sequenceNumber)
            return ix
        }
        return ix
    }
}
