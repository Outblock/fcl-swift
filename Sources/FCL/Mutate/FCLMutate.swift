//
//  File.swift
//
//
//  Created by lmcmz on 20/10/21.
//

import Foundation
import Flow
import BigInt
import Combine

extension FCL {
    /// Submit scripts to query the blockchain.
    /// - parameters:
    ///     - signers: A list of `FlowSigner` to sign the transaction
    /// - returns: Future<`Flow.ScriptResponse`, Error>.
    public func `query`(@Flow .TransactionBuilder builder: () -> [Flow.TransactionBuild]) -> Future<Flow.ScriptResponse, Error> {
        var script: Flow.Script = .init(data: Data())
        var args: [Flow.Argument] = []
        builder().forEach { txValue in
            switch txValue {
            case let .script(value):
                script = value
            case let .argument(value):
                args = value
            default:
                break
            }
        }
        let call = flow.accessAPI.executeScriptAtLatestBlock(script: script, arguments: args)
        return call.toFuture()
    }

    //    public func verifyUserSignatures(message: String, signatures: [Flow.TransactionSignature]) -> Future<Bool, Error> {
    //        let call = try flow.verifyUserSignature(message: message, signatures: signatures)
    //        call.whenSuccess { response in
    //            response.fields?.value.toBool()
    //        }
    //    }

    func send(ix: Interaction? = nil ) -> Future<Interaction, Error> {
        return Future { promise in

            let resolvers: [Resolver] = [CadenceResolver(),
                                         AccountsResolver(),
                                         RefBlockResolver(),
                                         SequenceNumberResolver(),
                                         SignatureResolver()]

            self.pipe(ix: ix ?? Interaction(), resolvers: resolvers).sink { completion  in
                if case let .failure(error) = completion {
                    promise(.failure(error))
                }
            } receiveValue: { ix in
                promise(.success(ix))
            }.store(in: &fcl.cancellables)

        }
    }

    func pipe(ix: Interaction, resolvers: [Resolver]) -> Future<Interaction, Error> {

        if let resolver = resolvers.first {
            return resolver.resolve(ix: ix).flatMap { newIX in
                self.pipe(ix: newIX, resolvers: Array(resolvers.dropFirst()))
            }.asFuture()
        } else {
            return Future { $0(.success(ix))  }
        }
    }

    func sendIX(ix: Interaction) -> Future<Flow.ID, Error> {
        return ix.toFlowTransaction().flatMap { tx in
            flow.accessAPI.sendTransaction(transaction: tx).toFuture()
        }.asFuture()
    }

    public func mutate(@Flow .TransactionBuilder builder: () -> [Flow.TransactionBuild]) -> Future<String, Error> {

        var script: Flow.Script = .init(data: Data())
        var args: [Flow.Argument] = []
        var gasLimit = BigUInt(100)

        builder().forEach { txValue in
            switch txValue {
            case let .script(value):
                script = value
            case let .argument(value):
                args = value
            case let .gasLimit(value):
                gasLimit = value
            default:
                break
            }
        }

        let cadenceString = String(data: script.data, encoding: .utf8)!
        let fclArgs = args.toFCLArguments()

        var ix = Interaction()
        ix.tag = .transaction
        ix.message.cadence = cadenceString
        ix.status = .ok
        ix.arguments = fclArgs

        //        let object = PreSignable(
        //            roles: Role(proposer: true, authorizer: false, payer: true, param: false),
        //            cadence: cadenceString,
        //            args: args,
        //            interaction: Interaction(tag: .transaction,
        //                                     status: .ok,
        //                                     arguments: fclArgs,
        //                                     message: Message(cadence: cadenceString,
        //                                                      refBlock: "",
        //                                                      computeLimit: Int(gasLimit),
        //                                                      arguments: Array(fclArgs.keys)),
        //                                     proposer: nil,
        //                                     authorizations: [],
        //                                     payer: nil
        //            )
        //        )
        return send(ix: ix).flatMap { self.sendIX(ix: $0) }.map { $0.hex }.asFuture()
    }
}
