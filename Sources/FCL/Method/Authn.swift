//
//  File.swift
//
//
//  Created by Hao Fu on 25/9/2022.
//

import Flow
import Foundation

public extension FCL {
    func unauthenticate() {
        currentUser = nil
    }

    internal func reauthenticate() async throws -> FCL.Response {
        unauthenticate()
        return try await authenticate()
    }

    func authenticate() async throws -> FCL.Response {
        guard let endpoint = config.get(.authn), let url = URL(string: endpoint) else {
            throw Flow.FError.urlEmpty
        }
        
        let response = try await fcl.getStategy().execService(url: url, method: .authn, request: FCL.Status.approved)
        fcl.currentUser = buildUser(authn: response)
        return response
    }
}
