//
//  File.swift
//  File
//
//  Created by lmcmz on 11/10/21.
//

import Combine
import Flow
import Foundation

class InteractionWrapper {
    let ix: Interaction

    init(ix: Interaction) {
        self.ix = ix
    }
}

final class SignatureResolver: Resolver {
    func resolve(ix: inout Interaction) async throws -> Interaction {
        guard ix.tag == .transaction else {
            return ix
        }

        let insideSigners = ix.findInsideSigners

        // TODO: Use FlatMap here
        let tx = try await ix.toFlowTransaction()
        ix.accounts[ix.proposer ?? ""]?.sequenceNum = Int(tx.proposalKey.sequenceNumber)

        guard let insidePayload = tx.signablePlayload?.hexValue else {
            throw FCLError.generic
        }

        let copyIX = ix
        let list = try await withThrowingTaskGroup(of: (String, String).self, returning: [(String, String)].self) { group in
            insideSigners.forEach { address in
                group.addTask {
                    try await self.fetchSignature(ix: copyIX, payload: insidePayload, id: address)
                }
            }

            return try await group.reduce(into: [(String, String)]()) { result, response in
                result.append(response)
            }
        }

        list.forEach { id, signature in
            ix.accounts[id]?.signature = signature
        }

        let outsideSigners = ix.findOutsideSigners
        let copyIX2 = ix
        if let outsidePayload = encodeOutsideMessage(transaction: tx, ix: ix, insideSigners: insideSigners) {
            let list = try await withThrowingTaskGroup(of: (String, String).self, returning: [(String, String)].self) { group in
                outsideSigners.forEach { address in
                    group.addTask {
                        try await self.fetchSignature(ix: copyIX2, payload: outsidePayload, id: address)
                    }
                }

                return try await group.reduce(into: [(String, String)]()) { result, response in
                    result.append(response)
                }
            }

            list.forEach { id, signature in
                ix.accounts[id]?.signature = signature
            }
        }
        return ix
    }

    func fetchSignature(ix: Interaction, payload: String, id: String) async throws -> (String, String) {
//        let ix = wrapper.ix
        guard let acct = ix.accounts[id],
              let signable = buildSignable(ix: ix, payload: payload, account: acct)
        else {
            throw FCLError.generic
        }

        let response = try await acct.signingFunction(signable: signable)
        return (id, (response.data?.signature ?? response.compositeSignature?.signature) ?? "")
    }

    func encodeOutsideMessage(transaction: Flow.Transaction, ix: Interaction, insideSigners: [String]) -> String? {
        var tx = transaction
        insideSigners.forEach { address in
            if let account = ix.accounts[address],
               let address = account.addr,
               let keyId = account.keyID,
               let signature = account.signature
            {
                tx.addPayloadSignature(address: Flow.Address(hex: address),
                                       keyIndex: keyId,
                                       signature: Data(signature.hexValue))
            }
        }

        return tx.signableEnvelope?.hexValue
    }

    func buildSignable(ix: Interaction, payload: String, account: SignableUser) -> Signable? {
        return Signable(message: payload,
                        keyId: account.keyID,
                        addr: account.addr,
                        roles: account.role,
                        cadence: ix.message.cadence,
                        args: ix.message.arguments.compactMap { tempId in
                            ix.arguments[tempId]?.asArgument
                        }, // TODO: Add args
                        interaction: ix)
    }
}
