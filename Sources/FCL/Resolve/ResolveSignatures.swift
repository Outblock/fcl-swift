//
//  File.swift
//  File
//
//  Created by lmcmz on 11/10/21.
//

import Combine
import Flow
import Foundation

func resolveSignatures(interaction: Interaction) -> Future<Interaction, Error> {
    return Future { promise in
        var ix = interaction

        guard ix.tag == "TRANSACTION" else {
            promise(.failure(FCLError.generic))
            return
        }

        let insideSigners = findInsideSigners(ix: ix)

        guard let tx = toFlowTransaction(ix: ix) else {
            promise(.failure(FCLError.generic))
            return
        }

        ix.accounts[ix.proposer ?? ""]?.sequenceNum = Int(tx.proposalKey.sequenceNumber)

        guard let insidePayload = tx.signablePlayload?.hexValue else {
            promise(.failure(FCLError.generic))
            return
        }

        let publishers = insideSigners.map { address in
            fetchSignature(ix: ix, payload: insidePayload, id: address)
        }.compactMap { $0.eraseToAnyPublisher() }

        let combined = Publishers.MergeMany(publishers).collect()

        combined.sink { completion in
            print(completion)
        } receiveValue: { list in
            list.forEach { id, signature in
                ix.accounts[id]?.signature = signature
            }

            let outsideSigners = findOutsideSigners(ix: ix)
            guard let outsidePayload = encodeOutsideMessage(transaction: tx, ix: ix, insideSigners: insideSigners) else {
                promise(.failure(FCLError.generic))
                return
            }

            let outPublishers = outsideSigners.map { address in
                fetchSignature(ix: ix, payload: outsidePayload, id: address)
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

//        combined.sink { completion in
//            if case let .failure(error) = completion {
//                print(error)
//            }
//        } receiveValue: { id, signature in
//            ix.accounts[id]?.signature = signature
//
//            OutCombined.sink { completion in
//                if case let .failure(error) = completion {
//                    print(error)
//                }
//            } receiveValue: { list in
//                list.forEach { id, signature in
//                    ix.accounts[id]?.signature = signature
//                }
//                promise(.success(ix))
//            }.store(in: &fcl.cancellables)
//        }.store(in: &fcl.cancellables)
    }
}

func fetchSignature(ix: Interaction, payload: String, id: String) -> Future<(String, String), Error> {
    return Future { promise in
        guard let acct = ix.accounts[id],
            let signingFunction = acct.signingFunction,
            let signable = buildSignable(ix: ix, payload: payload, account: acct),
            let data = try? JSONEncoder().encode(signable) else {
            promise(.failure(FCLError.generic))
            return
        }

        signingFunction(data).sink { completion in
            if case let .failure(error) = completion {
                promise(.failure(error))
            }
        } receiveValue: { response in
            if let signature = response.data?.signature {
                promise(.success((id, signature)))
            } else {
                promise(.failure(FCLError.generic))
            }
        }.store(in: &fcl.cancellables)
    }
}

func encodeInsideMessage(ix: inout Interaction) -> String? {
    guard let tx = toFlowTransaction(ix: ix) else { return nil }
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

func findInsideSigners(ix: Interaction) -> [String] {
    // Inside Signers Are: (authorizers + proposer) - payer
    var inside = Set(ix.authorizations)
    if let proposer = ix.proposer {
        inside.insert(proposer)
    }
    if let payer = ix.payer {
        inside.remove(payer)
    }
    return Array(inside)
}

func findOutsideSigners(ix: Interaction) -> [String] {
    // Outside Signers Are: (payer)
    guard let payer = ix.payer else {
        return []
    }
    let outside = Set([payer])
    return Array(outside)
}

// TODO: Move it to Interaction
func toFlowTransaction(ix: Interaction) -> Flow.Transaction? {
    guard let proposalKey = ix.createFlowProposalKey(),
        let payerAddress = ix.accounts[ix.payer ?? ""]?.addr else {
        return nil
    }

    var tx = try? flow.buildTransaction(fetchSequenceNumber: false) {
        cadence {
            ix.message.cadence ?? ""
        }

        refBlock {
            ix.message.refBlock ?? ""
        }

        gasLimit {
            ix.message.computeLimit ?? 10
        }

        arguments {
            ix.message.arguments.compactMap { try? JSONDecoder().decode(Flow.Argument.self, from: $0.data(using: .utf8)!) }
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

    let insideSigners = findInsideSigners(ix: ix)
    insideSigners.forEach { address in
        if let account = ix.accounts[address],
            let address = account.addr,
            let keyId = account.keyID,
            let signature = account.signature {
            tx?.addPayloadSignature(address: Flow.Address(hex: address),
                                    keyIndex: keyId,
                                    signature: Data(signature.hexValue))
        }
    }

    let outsideSigners = findOutsideSigners(ix: ix)

    outsideSigners.forEach { address in
        if let account = ix.accounts[address],
            let address = account.addr,
            let keyId = account.keyID,
            let signature = account.signature {
            tx?.addEnvelopeSignature(address: Flow.Address(hex: address),
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
                    args: ix.message.arguments, // TODO: Add args
                    interaction: ix)
}
