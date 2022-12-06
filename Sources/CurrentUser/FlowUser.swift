//
//  File.swift
//
//
//  Created by lmcmz on 5/9/21.
//

import Flow
import Foundation

public extension FCL {
    struct User: Codable {
        public let addr: Flow.Address
        public let keyId: Int
        public private(set) var loggedIn: Bool = false

        var fType: String = "USER"
        var fVsn: String = "1.0.0"
        var services: [FCL.Service]? = []
    }
}

extension FCL.User: FCLSigner {
    public var address: Flow.Address {
        addr
    }

    public var keyIndex: Int {
        keyId
    }

    public func signingFunction(signable: FCL.Signable) async throws -> AuthzResponse {
        guard let authzService = serviceOfType(services: services, type: .authz) else {
            throw FCLError.missingAuthz
        }

        return try await fcl.getStategy().execService(service: authzService, request: signable)
    }
}
