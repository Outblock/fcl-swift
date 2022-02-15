//
//  File.swift
//  File
//
//  Created by lmcmz on 10/10/21.
//

import Foundation

extension String {
    func sansPrefix() -> String {
        if hasPrefix("0x") || hasPrefix("Fx") {
            return String(dropFirst(2))
        }
        return self
    }

    func withPrefix() -> String {
        return "0x" + sansPrefix()
    }

    var hexValue: [UInt8] {
        var startIndex = self.startIndex
        return (0 ..< count / 2).compactMap { _ in
            let endIndex = index(after: startIndex)
            defer { startIndex = index(after: endIndex) }
            return UInt8(self[startIndex ... endIndex], radix: 16)
        }
    }
}
