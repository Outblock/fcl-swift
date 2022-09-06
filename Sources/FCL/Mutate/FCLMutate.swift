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
    public func query(@Flow.TransactionBuilder builder: () -> [Flow.TransactionBuild]) async throws -> Flow.ScriptResponse {
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

        // Imporve this
        let chainID: Flow.ChainID = fcl.config.get(.env) == "testnet" ? .testnet : .mainnet
        script = Flow.Script(text: fcl.defaultAddressRegistry.processScript(script: script.text, chainId: chainID))

        let items = fcl.config.dict.filter { item in
            item.key.range(of: "^0x", options: .regularExpression) != nil
        }

        let newScript = items.reduce(script.text) { partialResult, item in
            partialResult?.replacingOccurrences(of: item.key, with: item.value)
        } ?? ""

        return try await flow.accessAPI.executeScriptAtLatestBlock(script: Flow.Script(text: newScript), arguments: args)
    }

    //    public func verifyUserSignatures(message: String, signatures: [Flow.TransactionSignature]) -> Future<Bool, Error> {
    //        let call = try flow.verifyUserSignature(message: message, signatures: signatures)
    //        call.whenSuccess { response in
    //            response.fields?.value.toBool()
    //        }
    //    }

    func pipe(ix: inout Interaction, resolvers: [Resolver]) async throws -> Interaction {
        if let resolver = resolvers.first {
            _ = try await resolver.resolve(ix: &ix)
            return try await pipe(ix: &ix, resolvers: Array(resolvers.dropFirst()))
        } else {
            return ix
        }
    }

    func sendIX(ix: Interaction) async throws -> Flow.ID {
        let tx = try await ix.toFlowTransaction()
        return try await flow.accessAPI.sendTransaction(transaction: tx)
    }

    public func mutate(@Flow.TransactionBuilder builder: () -> [Flow.TransactionBuild]) async throws -> Flow.ID {
        return try await send(builder().compactMap { $0.toFCLBuild() })
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
