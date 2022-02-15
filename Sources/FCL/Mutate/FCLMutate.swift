//
//  File.swift
//
//
//  Created by lmcmz on 20/10/21.
//

import BigInt
import Combine
import Flow
import Foundation

extension FCL {
    /// Submit scripts to query the blockchain.
    /// - parameters:
    ///     - signers: A list of `FlowSigner` to sign the transaction
    /// - returns: Future<`Flow.ScriptResponse`, Error>.
    public func query(@Flow.TransactionBuilder builder: () -> [Flow.TransactionBuild]) -> Future<Flow.ScriptResponse, Error> {
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

        let items = fcl.config.dict.filter { item in
            item.key.range(of: "^0x", options: .regularExpression) != nil
        }

        let newScript = items.reduce(script.text) { partialResult, item in
            partialResult?.replacingOccurrences(of: item.key, with: item.value)
        } ?? ""

        let call = flow.accessAPI.executeScriptAtLatestBlock(script: Flow.Script(text: newScript), arguments: args)
        return call.toFuture()
    }

    //    public func verifyUserSignatures(message: String, signatures: [Flow.TransactionSignature]) -> Future<Bool, Error> {
    //        let call = try flow.verifyUserSignature(message: message, signatures: signatures)
    //        call.whenSuccess { response in
    //            response.fields?.value.toBool()
    //        }
    //    }

    func pipe(ix: Interaction, resolvers: [Resolver]) -> Future<Interaction, Error> {
        if let resolver = resolvers.first {
            return resolver.resolve(ix: ix).flatMap { newIX in
                self.pipe(ix: newIX, resolvers: Array(resolvers.dropFirst()))
            }.asFuture()
        } else {
            return Future { $0(.success(ix)) }
        }
    }

    func sendIX(ix: Interaction) -> Future<Flow.ID, Error> {
        return ix.toFlowTransaction().flatMap { tx in
            flow.accessAPI.sendTransaction(transaction: tx).toFuture()
        }.asFuture()
    }

    public func mutate(@Flow.TransactionBuilder builder: () -> [Flow.TransactionBuild]) -> Future<String, Error> {
        return send(builder().compactMap { $0.toFCLBuild() })
    }
}

extension Flow.TransactionBuild {
    func toFCLBuild() -> FCL.Build? {
        switch self {
        case let .script(value):
            guard let code = String(data: value.data, encoding: .utf8) else {
                return nil
            }
            return .transaction(code)
        case let .argument(args):
            return .args(args.compactMap { $0.value })
        case let .gasLimit(limit):
            return .limit(Int(limit))
        default:
            return nil
        }
    }
}
