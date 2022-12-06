//
//  File.swift
//  File
//
//  Created by lmcmz on 12/10/21.
//

import Combine
import Flow
import Foundation

extension FCL.Interaction {
    func getPayers() -> [FCL.SignableUser] {
        var result = accounts.values.filter { value in
            value.role.payer
        }

        result.sort(by: { ($0.signerIndex?[FCL.Roles.payer.rawValue] ?? 0) < ($1.signerIndex?[FCL.Roles.payer.rawValue] ?? 0) })

        if result.isEmpty {
            result.append(contentsOf: getAuthz())
        }

        return result
    }

    func getProposer() -> FCL.SignableUser? {
        var result = accounts.values.filter { value in
            value.role.proposer
        }

        if result.isEmpty {
            result.append(contentsOf: getAuthz())
        }

        return result.first
    }

    func getAuthorizers() -> [FCL.SignableUser] {
        var result = accounts.values.filter { value in
            value.role.authorizer
        }

        result.sort(by: { ($0.signerIndex?[FCL.Roles.authorizer.rawValue] ?? 0) < ($1.signerIndex?[FCL.Roles.authorizer.rawValue] ?? 0) })

        if result.isEmpty {
            result.append(contentsOf: getAuthz())
        }

        return result
    }

    func getAuthz() -> [FCL.SignableUser] {
        var result: [FCL.SignableUser] = []
        if let authzs = fcl.currentUser?.services?.filter({ $0.type == .authz }) {
            for authz in authzs {
                if let identity = authz.identity {
                    let tempID = [identity.address.addHexPrefix(), String(identity.keyId ?? 0)].joined(separator: "|")
                    result.append(
                        .init(kind: nil, tempID: tempID, addr: identity.address, signature: nil, keyID: identity.keyId,
                              sequenceNum: nil, role: FCL.Role(proposer: false, authorizer: false, payer: true))
                    )
                }
            }
        }

        return result
    }
}

final class AccountsResolver: Resolver {
    func resolve(ix: inout FCL.Interaction) async throws -> FCL.Interaction {
        if ix.isTransaction {
            return try await collectAccounts(ix: &ix, accounts: Array(ix.accounts.values))
        }
        return ix
    }

    private func authzService(identity: FCL.Identity) -> FCL.Service {
        return .init(fType: "Service",
                     fVsn: "1.0.0",
                     type: .authz,
                     method: .walletConnect,
                     endpoint: URL(string: fcl.config.get(.authn) ?? ""),
                     identity: identity,
                     data: nil)
    }

    private func prepareAccounts(ix: inout FCL.Interaction, currentUser: FCL.User) async throws -> FCL.Response {
        // Handle PreAuthz
        if let hasPreAuthz = currentUser.services?.contains(where: { $0.type == .preAuthz }), hasPreAuthz {
            guard let service = serviceOfType(services: currentUser.services, type: .preAuthz),
                  let endpoint = service.endpoint
            else {
                throw FCLError.missingPreAuthz
            }

            let preSignable = ix.buildPreSignable(role: FCL.Role())
            guard let url = buildURL(url: endpoint, params: service.params) else {
                throw FCLError.invaildURL
            }

            fcl.preAuthz = nil
            let response = try await fcl.getStategy().execService(url: url, method: .preAuthz, request: preSignable)
            fcl.preAuthz = response
            return response
        }

        // No PreAuthz
        guard let _ = currentUser.services?.filter({ $0.type == .authz }) else {
            throw FCLError.missingAuthz
        }

        return .init(fType: "PollingResponse",
                     fVsn: "1.0.0",
                     status: .approved,
                     data: .init(addr: currentUser.addr.hex,
                                 fType: "AuthnResponse",
                                 fVsn: "1.0.0",
                                 services: nil,
                                 proposer: ix.getProposer()?.toService(),
                                 payer: ix.getPayers().compactMap { $0.toService() },
                                 authorization: ix.getAuthorizers().compactMap { $0.toService() },
                                 signature: nil,
                                 keyId: nil))
    }

    func collectAccounts(ix: inout FCL.Interaction, accounts: [FCL.SignableUser]) async throws -> FCL.Interaction {
        guard let currentUser = fcl.currentUser, currentUser.loggedIn else {
            throw Flow.FError.unauthenticated
        }

        let response = try await prepareAccounts(ix: &ix, currentUser: currentUser)
        var signableUsers = try getAccounts(resp: response)
        var accounts = [String: FCL.SignableUser]()

        for user in ix.accounts.values {
            if signableUsers.contains(user) {
                continue
            }
            signableUsers.append(user)
        }

        signableUsers.sort(by: { ($0.signerIndex?[FCL.Roles.payer.rawValue] ?? 0) < ($1.signerIndex?[FCL.Roles.payer.rawValue] ?? 0) })
        signableUsers.sort(by: { ($0.signerIndex?[FCL.Roles.authorizer.rawValue] ?? 0) < ($1.signerIndex?[FCL.Roles.authorizer.rawValue] ?? 0) })

        signableUsers.forEach { user in
            if let addr = user.addr, let keyID = user.keyID {
                let tempID = [addr.addHexPrefix(), String(keyID)].joined(separator: "|")
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
        }
        ix.accounts = accounts
        return ix
    }

    func getAccounts(resp: FCL.Response) throws -> [FCL.SignableUser] {
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

            return FCL.SignableUser(tempID: [address.addHexPrefix(), String(keyId)].joined(separator: "|"),
                                    addr: address,
                                    keyID: keyId,
                                    role: FCL.Role(proposer: role == "PROPOSER",
                                                   authorizer: role == "AUTHORIZER",
                                                   payer: role == "PAYER",
                                                   param: nil),
                                    signer: service.signer)
        }
    }
}
