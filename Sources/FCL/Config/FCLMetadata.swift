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
        let appDescription: String
        let appIcon: URL
        let location: URL
        let autoConnect: Bool = true
        let accountProof: AccountProofConfig?
        let walletConnectConfig: WalletConnectConfig?

        public init(appName: String,
                    appDescription: String,
                    appIcon: URL,
                    location: URL,
                    autoConnect: Bool = true,
                    accountProof: FCL.Metadata.AccountProofConfig? = nil,
                    walletConnectConfig: FCL.Metadata.WalletConnectConfig? = nil) {
            self.appName = appName
            self.appDescription = appDescription
            self.appIcon = appIcon
            self.location = location
            self.autoConnect = autoConnect
            self.accountProof = accountProof
            self.walletConnectConfig = walletConnectConfig
        }
        
        public struct AccountProofConfig {
            let appIdentifier: String
            let nonce: String
            
            public init(appIdentifier: String, nonce: String) {
                self.appIdentifier = appIdentifier
                self.nonce = nonce
            }
        }

        public struct WalletConnectConfig {
            let urlScheme: String
            let projectID: String
            
            public init(urlScheme: String, projectID: String) {
                self.urlScheme = urlScheme
                self.projectID = projectID
            }
        }
    }
}
