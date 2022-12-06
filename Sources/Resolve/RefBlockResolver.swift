//
//  File.swift
//  File
//
//  Created by lmcmz on 1/11/21.
//

import Combine
import Flow
import Foundation

final class RefBlockResolver: Resolver {
    func resolve(ix: inout FCL.Interaction) async throws -> FCL.Interaction {
        if ix.isTransaction {
            let block = try await flow.accessAPI.getLatestBlock(sealed: true)
            ix.message.refBlock = block.id.hex
        }
        return ix
    }
}
