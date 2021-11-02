//
//  File.swift
//  File
//
//  Created by lmcmz on 1/11/21.
//

import Foundation
import Combine

extension Publisher {
    func asFuture() -> Future<Output, Failure> {
        return Future { promise in
            var ticket: AnyCancellable?
            ticket = self.sink(
                receiveCompletion: {
                    ticket?.cancel()
                    ticket = nil
                    switch $0 {
                    case .failure(let error):
                        promise(.failure(error))
                    case .finished:
                        // WHAT DO WE DO HERE???
                        fatalError()
                    }
                },
                receiveValue: {
                    ticket?.cancel()
                    ticket = nil
                    promise(.success($0))
                })
        }
    }
}
