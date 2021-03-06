//
//  File.swift
//  File
//
//  Created by lmcmz on 12/10/21.
//

import Combine
import Flow
import Foundation

final class AccountsResolver: Resolver {
    func resolve(ix: inout Interaction) async throws -> Interaction {
        if ix.isTransaction {
            return try await collectAccounts(ix: &ix, accounts: Array(ix.accounts.values))
        }
        return ix
    }

    func collectAccounts(ix: inout Interaction, accounts: [SignableUser]) async throws -> Interaction {
        guard let currentUser = fcl.currentUser, currentUser.loggedIn else {
            throw Flow.FError.unauthenticated
        }

        guard let service = fcl.serviceOfType(services: currentUser.services, type: .preAuthz),
              let endpoint = service.endpoint
        else {
            throw FCLError.missingPreAuthz
        }

        let preSignable = ix.buildPreSignable(role: Role())
        guard let data = try? JSONEncoder().encode(preSignable) else {
            throw FCLError.encodeFailure
        }

        let response = try await fcl.api.execHttpPost(url: endpoint, params: service.params, data: data)
        let signableUsers = getAccounts(resp: response)
        var accounts = [String: SignableUser]()

        ix.authorizations.removeAll()
        signableUsers.forEach { user in
            let tempID = [user.addr!, String(user.keyID!)].joined(separator: "-")
            var temp = user
            temp.tempID = tempID

            if accounts.keys.contains(tempID) {
                accounts[tempID]?.role.merge(role: temp.role)
            }
            accounts[tempID] = temp

            if user.role.proposer {
                ix.proposer = tempID
            }

            if user.role.payer {
                ix.payer = tempID
            }

            if user.role.authorizer {
                ix.authorizations.append(tempID)
            }
        }
        ix.accounts = accounts
        return ix
    }

    func getAccounts(resp: AuthnResponse) -> [SignableUser] {
        var axs = [(role: String, service: Service)]()
        if let proposer = resp.data?.proposer {
            axs.append(("PROPOSER", proposer))
        }
        for az in resp.data?.payer ?? [] {
            axs.append(("PAYER", az))
        }
        for az in resp.data?.authorization ?? [] {
            axs.append(("AUTHORIZER", az))
        }

        return axs.compactMap { role, service in

            guard let address = service.identity?.address,
                  let keyId = service.identity?.keyId
            else {
                return nil
            }

            return SignableUser(tempID: [address, String(keyId)].joined(separator: "|"),
                                addr: address,
                                keyID: keyId,
                                role: Role(proposer: role == "PROPOSER",
                                           authorizer: role == "AUTHORIZER",
                                           payer: role == "PAYER",
                                           param: nil)) { data in
                Task {
                    try await fcl.api.execHttpPost(service: service, data: data)
                }
            }
        }
    }
}
