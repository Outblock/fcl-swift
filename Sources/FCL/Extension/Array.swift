//
//  File.swift
//  File
//
//  Created by lmcmz on 10/10/21.
//

import Flow
import Foundation

extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

extension Array where Element == Flow.Argument {
    func toFCLArguments() -> [(String, FCL.Argument)] {
        var list = [(String, FCL.Argument)]()
        forEach { arg in
            let fclArg = arg.toFCLArgument()
            list.append((fclArg.tempId, fclArg))
        }
        return list
    }
}
