//
//  File.swift
//  File
//
//  Created by lmcmz on 1/11/21.
//

import Combine
import Foundation

final class CadenceResolver: Resolver {
    func resolve(ix: inout Interaction) async throws -> Interaction {
        if ix.isTransaction || ix.isScript {
            let items = fcl.config.dict.filter { item in
                item.key.range(of: "^0x", options: .regularExpression) != nil
            }

            ix.message.cadence = items.reduce(ix.message.cadence) { partialResult, item in
                partialResult?.replacingOccurrences(of: item.key, with: item.value)
            }
            return ix
        }
        return ix
    }
}
