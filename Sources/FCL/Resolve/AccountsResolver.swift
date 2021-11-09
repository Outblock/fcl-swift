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
    func resolve(ix: Interaction) -> Future<Interaction, Error> {
        if ix.isTransaction {
            return collectAccounts(ix: ix, accounts: Array(ix.accounts.values))
        }

        return Future { $0(.success(ix)) }
    }

    func collectAccounts(ix: Interaction, accounts: [SignableUser]) -> Future<Interaction, Error> {
        return Future { promise in

            guard let currentUser = fcl.currentUser, currentUser.loggedIn else {
                promise(.failure(Flow.FError.unauthenticated))
                return
            }

            guard let service = fcl.serviceOfType(services: currentUser.services, type: .preAuthz),
                  let endpoint = service.endpoint else {
                promise(.failure(FCLError.missingPreAuthz))
                return
            }

            let preSignable = ix.buildPreSignable(role: Role())
            guard let data = try? JSONEncoder().encode(preSignable) else {
                promise(.failure(FCLError.encodeFailure))
                return
            }

            fcl.api.execHttpPost(url: endpoint, params: service.params, data: data)
                .sink { completion in
                    if case let .failure(error) = completion {
                        promise(.failure(error))
                    }
                } receiveValue: { response in
                    let signableUsers = self.getAccounts(resp: response)
                    var accounts = [String: SignableUser]()

                    var newIX = ix
                    newIX.authorizations.removeAll()
                    signableUsers.forEach { user in
                        let tempID = [user.addr!, String(user.keyID!)].joined(separator: "-")
                        var temp = user
                        temp.tempID = tempID

                        if accounts.keys.contains(tempID) {
                            accounts[tempID]?.role.merge(role: temp.role)
                        }
                        accounts[tempID] = temp

                        if user.role.proposer {
                            newIX.proposer = tempID
                        }

                        if user.role.payer {
                            newIX.payer = tempID
                        }

                        if user.role.authorizer {
                            newIX.authorizations.append(tempID)
                        }
                    }
                    newIX.accounts = accounts
                    promise(.success(newIX))
                }.store(in: &fcl.cancellables)
        }
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
                  let keyId = service.identity?.keyId else {
                return nil
            }

            return SignableUser(tempID: [address, String(keyId)].joined(separator: "|"),
                                addr: address,
                                keyID: keyId,
                                role: Role(proposer: role == "PROPOSER",
                                           authorizer: role == "AUTHORIZER",
                                           payer: role == "PAYER",
                                           param: nil)) { data in
                fcl.api.execHttpPost(service: service, data: data).eraseToAnyPublisher()
            }
        }
    }
}
