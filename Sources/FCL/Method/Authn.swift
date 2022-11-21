//
//  File.swift
//
//
//  Created by Hao Fu on 25/9/2022.
//

import Flow
import Foundation
import WalletConnectKMS

extension String {
    enum StorageKey: String {
        case currentUser
        case wcSession
    }
    
    enum PreferenceKey: String {
        case provider
        case env
    }
}

public extension FCL {
    func unauthenticate() {
        currentUser = nil
        Task {
            try? await fcl.wcProvider?.disconnect()
        }
        
        try? fcl.keychain.deleteAll()
    }

    func reauthenticate() async throws -> FCL.Response {
        unauthenticate()
        return try await authenticate()
    }

    func authenticate() async throws -> FCL.Response {
        guard let endpoint = config.get(.authn),
                let url = URL(string: endpoint) else {
            throw Flow.FError.urlEmpty
        }
        
        let response = try await fcl.getStategy().execService(url: url, method: .authn, request: FCL.Status.approved)
        let currentUser = buildUser(authn: response)
        fcl.currentUser = currentUser
        
        if let currentUser, let data = try? JSONEncoder().encode(currentUser) {
            try? fcl.keychain.add(data: data, forKey: .StorageKey.currentUser.rawValue)
        }
        
        return response
    }
    
    internal func buildUser(authn: FCL.Response) -> FCL.User? {
        guard let address = authn.data?.addr else { return nil }
        return FCL.User(addr: Flow.Address(hex: address),
                        keyId: authn.data?.keyId ?? 0,
                        loggedIn: true,
                        services: authn.data?.services)
    }
}
