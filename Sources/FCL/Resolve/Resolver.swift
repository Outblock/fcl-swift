//
//  File.swift
//  File
//
//  Created by lmcmz on 1/11/21.
//

import Combine
import Foundation

protocol Resolver {
    func resolve(ix: inout Interaction) async throws -> Interaction
}
