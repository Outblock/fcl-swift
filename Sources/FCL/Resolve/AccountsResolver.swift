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
    
//    private func authzService(identity: FCL.Identity) -> FCL.Service {
//        return .init(fType: "Service",
//                     fVsn: "1.0.0",
//                     type: .authz,
//                     method: .walletConnect,
//                     endpoint: FCL.WCMethod(service: type)?.rawValue,
//                     identity: identity)
//    }

    
    private func prepareAccounts(ix: inout Interaction, currentUser: FCL.User) async throws -> FCL.Response {
        
        // Handle PreAuthz
//        if let hasPreAuthz = currentUser.services?.contains(where: { $0.type == .preAuthz }), hasPreAuthz {
            
            guard let service = serviceOfType(services: currentUser.services, type: .preAuthz),
                  let endpoint = service.endpoint
            else {
                throw FCLError.missingPreAuthz
            }

            let preSignable = ix.buildPreSignable(role: Role())
            guard let url = buildURL(url: endpoint, params: service.params) else {
                throw FCLError.invaildURL
            }
        
            fcl.preAuthz = nil
        
            let response = try await fcl.getStategy().execService(url: url, method: .preAuthz, request: preSignable)
            fcl.preAuthz = response
            return response
//        }
//
//        // No PreAuthz
//        guard let authzList = currentUser.services?.filter({ $0.type == .authz }) else {
//            throw FCLError.missingAuthz
//        }
//
//
//        // TODO FIX custom authz
//        return .init(fType: "PollingResponse",
//                     fVsn: "1.0.0",
//                     status: .approved,
//                     data: .init(addr: currentUser.addr.hex,
//                                 fType: "AuthnResponse",
//                                 fVsn: "1.0.0",
//                                 proposer: authzService(identity: <#T##FCL.Identity#>),
//                                 payer: <#T##[FCL.Service]?#>,
//                                 authorization: <#T##[FCL.Service]?#>,
//                                 signature: nil,
//                                 keyId: nil))
    }

    func collectAccounts(ix: inout Interaction, accounts: [SignableUser]) async throws -> Interaction {
        guard let currentUser = fcl.currentUser, currentUser.loggedIn else {
            throw Flow.FError.unauthenticated
        }
        
        let response = try await prepareAccounts(ix: &ix, currentUser: currentUser)
        let signableUsers = try getAccounts(resp: response)
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
    
    func authzOnly(ix: inout Interaction, accounts: [SignableUser]) async throws -> Interaction {
        
        return ix
    }

    func getAccounts(resp: FCL.Response) throws -> [SignableUser] {
        var axs = [(role: String, service: FCL.Service)]()
        if let proposer = resp.data?.proposer {
            axs.append(("PROPOSER", proposer))
        }
        for az in resp.data?.payer ?? [] {
            axs.append(("PAYER", az))
        }
        for az in resp.data?.authorization ?? [] {
            axs.append(("AUTHORIZER", az))
        }

        return try axs.compactMap { role, service in

            guard let address = service.identity?.address,
                  let keyId = service.identity?.keyId
            else {
                throw FCLError.invalidResponse
            }

            return SignableUser(tempID: [address, String(keyId)].joined(separator: "|"),
                                addr: address,
                                keyID: keyId,
                                role: Role(proposer: role == "PROPOSER",
                                           authorizer: role == "AUTHORIZER",
                                           payer: role == "PAYER",
                                           param: nil))
        }
    }
}

