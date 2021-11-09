//
//  File.swift
//  File
//
//  Created by lmcmz on 31/10/21.
//

import Combine
import Foundation
import NIO

extension EventLoopFuture {
    func toFuture() -> Future<Value, Error> {
        return Future { promise in
            self.whenComplete { result in
                switch result {
                case let .success(response):
                    promise(.success(response))
                case let .failure(error):
                    promise(.failure(error))
                }
            }
        }
    }
}
