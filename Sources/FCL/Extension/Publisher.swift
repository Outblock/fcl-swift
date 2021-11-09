//
//  File.swift
//  File
//
//  Created by lmcmz on 1/11/21.
//

import Combine
import Foundation

extension Publisher {
    func asFuture() -> Future<Output, Failure> {
        return Future { promise in
            var ticket: AnyCancellable?
            ticket = self.sink(
                receiveCompletion: {
                    ticket?.cancel()
                    ticket = nil
                    switch $0 {
                    case let .failure(error):
                        promise(.failure(error))
                    case .finished:
                        // TODO: Add finish hanlder
                        break
                    }
                },
                receiveValue: {
                    ticket?.cancel()
                    ticket = nil
                    promise(.success($0))
                }
            )
        }
    }
}
