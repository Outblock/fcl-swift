//
//  File.swift
//  File
//
//  Created by lmcmz on 12/10/21.
//

import Foundation
import Combine

final class ResolveAccounts: Resolver {

    func resolve(ix: Interaction) -> Future<Interaction, Error> {
        return Future { promise in

            if (ix.isTransaction || ix.isScript) {
                // TODO: Implement this

            }
            promise(.success(ix))
        }
    }

    func resolveAccounts(interaction: Interaction) {
        var ix = interaction
        guard ix.tag == .transaction else {
            //        promise(.failure(FCLError.generic))
            return
        }

        ix.accounts.values.forEach { ax in

            if let addr = ax.addr, let keyId = ax.keyID {
                //          ax.tempID = "\(ax.addr)-\(ax.keyId)"
            }

            //        ix.accounts[ax.tempID]
        }
    }
}
