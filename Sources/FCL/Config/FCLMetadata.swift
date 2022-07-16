//
//  File.swift
//  
//
//  Created by Hao Fu on 17/7/2022.
//

import Foundation

extension FCL {
    public struct Metadata {
        let appName: String
        let appIcon: String
        let location: String
        
        public init(appName: String, appIcon: String, location: String) {
            self.appName = appName
            self.appIcon = appIcon
            self.location = location
        }
    }
}
