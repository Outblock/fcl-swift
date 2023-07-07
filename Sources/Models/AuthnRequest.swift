//
//  File.swift
//
//
//  Created by lmcmz on 28/8/21.
//

import Foundation
import Flow

public struct BaseConfigRequest: Encodable {
    var app: [String: String] = fcl.config.configLens("^app\\.detail\\.")
    var service: [String: String] = fcl.config.configLens("^service\\.")
    var client = ClientInfo()

    var appIdentifier: String = fcl.config.get(.appId) ?? ""
    var accountProofNonce: String = fcl.config.get(.nonce) ?? ""
    
    var config = AppConfig()
}

public struct AppConfig: Encodable {
    var app: [String: String] = fcl.config.configLens("^app\\.detail\\.")
}

public struct ClientInfo: Encodable {
    var fclVersion: String = fcl.version
    var fclLibrary = URL(string: "https://github.com/Outblock/fcl-swift")!

    @NullEncodable
    var hostname: String? = nil
}

public struct AuthnRequest: Codable {
    let fType: String
    let fVsn: String
    let type: String?
    let endpoint: String
    let method: String
}

public struct FCLUserSignatureResponse {
    let addr: String
    let keyId: Int
    let signature: String
}
