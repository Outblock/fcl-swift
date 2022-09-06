//
//  File.swift
//
//
//  Created by Hao Fu on 17/7/2022.
//

import Foundation

public extension FCL {
    struct Metadata {
        let appName: String
        let appIcon: String
        let location: String
        let appIdentifier: String
        let nonce: String

        public init(appName: String, appIcon: String, location: String, appIdentifier: String, nonce: String) {
            self.appName = appName
            self.appIcon = appIcon
            self.location = location
            self.appIdentifier = appIdentifier
            self.nonce = nonce
        }
    }
}
