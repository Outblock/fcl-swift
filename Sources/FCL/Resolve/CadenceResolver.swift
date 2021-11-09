//
//  File.swift
//  File
//
//  Created by lmcmz on 1/11/21.
//

import Combine
import Foundation

final class CadenceResolver: Resolver {
    func resolve(ix: Interaction) -> Future<Interaction, Error> {
        return Future { promise in
            if ix.isTransaction || ix.isScript {
                let items = fcl.config.dict.filter { item in
                    item.key.range(of: "^0x", options: .regularExpression) != nil
                }

                var newIx = ix
                newIx.message.cadence = items.reduce(newIx.message.cadence) { partialResult, item in
                    partialResult?.replacingOccurrences(of: item.key, with: item.value)
                }
                promise(.success(newIx))
            }
            promise(.success(ix))
        }
    }
}
