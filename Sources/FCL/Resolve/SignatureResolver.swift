//
//  File.swift
//  File
//
//  Created by lmcmz on 11/10/21.
//

import Combine
import Flow
import Foundation

final class SignatureResolver: Resolver {
    func resolve(ix interaction: Interaction) -> Future<Interaction, Error> {
        return Future { promise in
            var ix = interaction

            guard ix.tag == .transaction else {
                promise(.failure(FCLError.generic))
                return
            }

            let insideSigners = interaction.findInsideSigners

            // TODO: Use FlatMap here
            ix.toFlowTransaction().sink { completion in
                if case let .failure(error) = completion {
                    promise(.failure(error))
                }
            } receiveValue: { tx in
                ix.accounts[ix.proposer ?? ""]?.sequenceNum = Int(tx.proposalKey.sequenceNumber)

                guard let insidePayload = tx.signablePlayload?.hexValue else {
                    promise(.failure(FCLError.generic))
                    return
                }

                let publishers = insideSigners.map { address in
                    self.fetchSignature(ix: ix, payload: insidePayload, id: address)
                }.compactMap { $0 }

                Publishers.MergeMany(publishers).collect()
                    .flatMap { list -> Publishers.Collect<Publishers.MergeMany<AnyPublisher<(String, String), Error>>> in
                        list.forEach { id, signature in
                            ix.accounts[id]?.signature = signature
                        }

                        let outsideSigners = ix.findOutsideSigners
                        var outPublishers: [AnyPublisher<(String, String), Error>] = []
                        if let outsidePayload = self.encodeOutsideMessage(transaction: tx, ix: ix, insideSigners: insideSigners) {
                            outPublishers = outsideSigners.map { address in
                                self.fetchSignature(ix: ix, payload: outsidePayload, id: address)
                            }.compactMap { $0.eraseToAnyPublisher() }

                        }
                        return Publishers.MergeMany(outPublishers).collect()
                    }.sink { completion in
                        if case let .failure(error) = completion {
                            print(error)
                        }
                    } receiveValue: { list in
                        list.forEach { id, signature in
                            ix.accounts[id]?.signature = signature
                        }
                        promise(.success(ix))
                    }.store(in: &fcl.cancellables)
            }.store(in: &fcl.cancellables)
        }
    }

    func fetchSignature(ix: Interaction, payload: String, id: String) -> AnyPublisher<(String, String), Error> {
        guard let acct = ix.accounts[id],
              let signingFunction = acct.signingFunction,
              let signable = buildSignable(ix: ix, payload: payload, account: acct),
              let data = try? JSONEncoder().encode(signable) else {
            return Result.Publisher(FCLError.generic).eraseToAnyPublisher()
        }

        return signingFunction(data).map { response in
            (id, response.data!.signature!)
        }.eraseToAnyPublisher()
    }

    func encodeOutsideMessage(transaction: Flow.Transaction, ix: Interaction, insideSigners: [String]) -> String? {
        var tx = transaction
        insideSigners.forEach { address in
            if let account = ix.accounts[address],
               let address = account.addr,
               let keyId = account.keyID,
               let signature = account.signature {
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
