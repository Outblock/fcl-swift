//
//  File.swift
//  File
//
//  Created by lmcmz on 1/11/21.
//

import Foundation
import Combine
import Flow

final class ResolveSequenceNumber: Resolver {
    func resolve(ix: Interaction) -> Future<Interaction, Error> {
        return Future { promise in

            guard let proposer = ix.message.proposer,
                  let account = ix.accounts[proposer],
                  let address = account.addr,
                  let keyID = account.keyID else {
                promise(.failure(FCLError.generic))
                return
            }

            let flowAddress = Flow.Address(hex: address)

            if account.sequenceNum == nil {
                let call = flow.accessAPI.getAccountAtLatestBlock(address: flowAddress)
                call.unwrap(orError: FCLError.generic).whenSuccess { accountData in
                    var newIX = ix
                    newIX.accounts[proposer]?.sequenceNum = accountData.keys[keyID].sequenceNumber
                    promise(.success(newIX))
                }

                call.whenFailure { error in
                    promise(.failure(error))
                }

            } else {
                promise(.success(ix))
            }

        }
    }

}
