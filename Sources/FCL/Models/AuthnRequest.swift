//
//  File.swift
//
//
//  Created by lmcmz on 28/8/21.
//

import Foundation

public struct BaseConfigRequest: Encodable {
    var app: [String: String] = fcl.config.configLens("^app\\.detail\\.")
    var service: [String: String] = fcl.config.configLens("^service\\.")
    var client = ClientInfo()
//    var body = AccountProof()

    var appIdentifier: String = fcl.config.get(.appId) ?? ""
    var accountProofNonce: String = fcl.config.get(.nonce) ?? ""
}

// public struct AccountProof: Codable {
//    var appIdentifier: String = fcl.config.get(.appId) ?? ""
//    var accountProofNonce: String = fcl.config.get(.nonce) ?? ""
// }

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
    //    var data: Dictionary<String, String>?
    //    var parameter: Dictionary<String, String>?
}
