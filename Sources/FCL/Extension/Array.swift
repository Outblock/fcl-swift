//
//  File.swift
//  File
//
//  Created by lmcmz on 10/10/21.
//

import Foundation
import Flow

extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

extension Array where Element == Flow.Argument {
    func toFCLArguments() -> [(String, Argument)] {
        var list = [(String,Argument)]()
        forEach { arg in
            let fclArg = arg.toFCLArgument()
            list.append((fclArg.tempId, fclArg))
        }
        return list
    }
}
