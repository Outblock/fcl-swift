//
//  File.swift
//  File
//
//  Created by lmcmz on 1/11/21.
//

import Foundation
import Combine

protocol Resolver {
    func resolve(ix: Interaction) -> Future<Interaction, Error>
}
