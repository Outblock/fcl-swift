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

    public func verifyUserSignatures() {

    }

    //    public func send(@Flow .TransactionBuilder builder: () -> [Flow.TransactionBuild]) -> Future<Flow.ID, Error> {
    ////        flow.sendTransaction(signers: <#T##[FlowSigner]#>, builder: <#T##() -> [Flow.TransactionBuild]#>)
    //    }

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

        let object = PreSignable(
            roles: Role(proposer: true, authorizer: false, payer: true, param: false),
            cadence: cadenceString,
            args: args,
            interaction: Interaction(tag: "TRANSACTION",
                                     status: "OK",
                                     arguments: fclArgs,
                                     message: Message(cadence: cadenceString,
                                                      refBlock: "",
                                                      computeLimit: Int(gasLimit),
                                                      arguments: Array(fclArgs.keys)),
                                     proposer: nil,
                                     authorizations: [],
                                     payer: nil
            )
        )

        return fcl.authz(presignable: object)
    }
}
