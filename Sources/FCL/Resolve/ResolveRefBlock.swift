//
//  File.swift
//  File
//
//  Created by lmcmz on 1/11/21.
//

import Foundation
import Combine
import Flow

final class ResolveRefBlock: Resolver {
    func resolve(ix: Interaction) -> Future<Interaction, Error> {
        return Future { promise in
            let call = flow.accessAPI.getLatestBlock(sealed: true)
            call.whenSuccess { block in
                var newIX = ix
                newIX.message.refBlock = block.id.hex
                promise(.success(newIX))
            }

            call.whenFailure { error in
                promise(.failure(error))
            }
        }
    }
}
