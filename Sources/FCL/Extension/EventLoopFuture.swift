//
//  File.swift
//  File
//
//  Created by lmcmz on 31/10/21.
//

import Foundation
import NIO
import Combine

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
