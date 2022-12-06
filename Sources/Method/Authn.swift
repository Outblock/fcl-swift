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
    func unauthenticate() async throws {
        currentUser = nil
        try await fcl.wcProvider?.disconnect()
        try fcl.keychain.deleteAll()
    }

    func reauthenticate() async throws -> FCL.Response {
        try? await unauthenticate()
        return try await authenticate()
    }

    func authenticate() async throws -> FCL.Response {
        guard let endpoint = config.get(.authn),
              let url = URL(string: endpoint)
        else {
            throw Flow.FError.urlEmpty
        }

        let response = try await fcl.getStategy().execService(url: url, method: .authn, request: FCL.Status.approved)
        let currentUser = buildUser(authn: response)
        await MainActor.run {
            fcl.currentUser = currentUser
        }

        if let currentUser, let data = try? JSONEncoder().encode(currentUser),
           let provider = fcl.currentProvider,
           provider.supportAutoConnect
        {
            try? fcl.keychain.add(data: data, forKey: .StorageKey.currentUser.rawValue)
        }

        return response
    }

    internal func buildUser(authn: FCL.Response) -> FCL.User? {
        guard let address = authn.data?.addr else { return nil }

        let authzService = authn.data?.services?.first(where: { $0.type == .authz })

        return FCL.User(addr: Flow.Address(hex: address),
                        keyId: authn.data?.keyId ?? authzService?.identity?.keyId ?? 0,
                        loggedIn: true,
                        services: authn.data?.services)
    }
}
