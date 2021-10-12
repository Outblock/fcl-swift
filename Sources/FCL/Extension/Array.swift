//
//  File.swift
//  File
//
//  Created by lmcmz on 10/10/21.
//

import Foundation

extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
