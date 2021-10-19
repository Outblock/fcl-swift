//
//  File.swift
//  File
//
//  Created by lmcmz on 12/10/21.
//

import Foundation

func resolveAccounts(interaction: Interaction) {
    var ix = interaction
    guard ix.tag == "TRANSACTION" else {
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
