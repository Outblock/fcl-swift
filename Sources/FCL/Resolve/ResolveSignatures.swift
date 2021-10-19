//
//  File.swift
//  File
//
//  Created by lmcmz on 11/10/21.
//

import Combine
import Flow
import Foundation

extension FCL {
    func resolveSignatures(interaction: Interaction) -> Future<Interaction, Error> {
        return Future { promise in
            var ix = interaction

            guard ix.tag == "TRANSACTION" else {
                promise(.failure(FCLError.generic))
                return
            }

            let insideSigners = interaction.findInsideSigners

            guard let tx = try? self.toFlowTransaction(ix: ix) else {
                promise(.failure(FCLError.generic))
                return
            }

            ix.accounts[ix.proposer ?? ""]?.sequenceNum = Int(tx.proposalKey.sequenceNumber)

            guard let insidePayload = tx.signablePlayload?.hexValue else {
                promise(.failure(FCLError.generic))
                return
            }

            let publishers = insideSigners.map { address in
                self.fetchSignature(ix: ix, payload: insidePayload, id: address)
            }.compactMap { $0 }

            let combined = Publishers.MergeMany(publishers).collect()

            combined.sink { completion in
                print(completion)
            } receiveValue: { list in

                list.forEach { id, signature in
                    ix.accounts[id]?.signature = signature
                }

                let outsideSigners = ix.findOutsideSigners
                guard let outsidePayload = self.encodeOutsideMessage(transaction: tx, ix: ix, insideSigners: insideSigners) else {
                    promise(.failure(FCLError.generic))
                    return
                }

                let outPublishers = outsideSigners.map { address in
                    self.fetchSignature(ix: ix, payload: outsidePayload, id: address)
                }.compactMap { $0.eraseToAnyPublisher() }

                let OutCombined = Publishers.MergeMany(outPublishers).collect()

                OutCombined.sink { completion in
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

    func encodeInsideMessage(ix: inout Interaction) -> String? {
        guard let tx = try? toFlowTransaction(ix: ix) else { return nil }
        ix.accounts[ix.proposer ?? ""]?.sequenceNum = Int(tx.proposalKey.sequenceNumber)
        return tx.signablePlayload?.hexValue
    }

    func encodeOutsideMessage(transaction: Flow.Transaction, ix: Interaction, insideSigners: [String]) -> String? {
        //    guard var tx = toFlowTransaction(ix: ix) else { return nil }
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

    // TODO: Move it to Interaction
    func toFlowTransaction(ix: Interaction) throws -> Flow.Transaction? {
        guard let proposalKey = ix.createFlowProposalKey(),
              let payerAddress = ix.accounts[ix.payer ?? ""]?.addr else {
            return nil
        }

        var tx = try flow.buildTransaction(fetchSequenceNumber: false) {
            cadence {
                ix.message.cadence ?? ""
            }

            refBlock {
                ix.message.refBlock ?? ""
            }

            gasLimit {
                ix.message.computeLimit ?? 100
            }

            arguments {
                ix.message.arguments.compactMap { tempId in
                    ix.arguments[tempId]?.asArgument
                }
            }

            proposer {
                proposalKey
            }

            payer {
                payerAddress
            }

            authorizers {
                ix.authorizations
                    .compactMap { cid in ix.accounts[cid]?.addr }
                    .uniqued()
                    .compactMap { Flow.Address(hex: $0) }
            }
        }

        let insideSigners = ix.findInsideSigners
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

        let outsideSigners = ix.findOutsideSigners

        outsideSigners.forEach { address in
            if let account = ix.accounts[address],
               let address = account.addr,
               let keyId = account.keyID,
               let signature = account.signature {
                tx.addEnvelopeSignature(address: Flow.Address(hex: address),
                                        keyIndex: keyId,
                                        signature: Data(signature.hexValue))
            }
        }

        return tx
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
