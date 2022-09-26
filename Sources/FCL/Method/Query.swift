//
//  File.swift
//  
//
//  Created by Hao Fu on 26/9/2022.
//

import Foundation
import Flow

public extension FCL {
    func query(script: String, args: [Flow.Argument]) async throws -> Flow.ScriptResponse {
        let chainID: Flow.ChainID = fcl.config.get(.env) == "testnet" ? .testnet : .mainnet
        let script = Flow.Script(text: fcl.defaultAddressRegistry.processScript(script: script, chainId: chainID))
        
        let items = fcl.config.dict.filter { item in
            item.key.range(of: "^0x", options: .regularExpression) != nil
        }
        
        let newScript = items.reduce(script.text) { partialResult, item in
            partialResult?.replacingOccurrences(of: item.key, with: item.value)
        } ?? ""
        
        return try await flow.accessAPI.executeScriptAtLatestBlock(script: Flow.Script(text: newScript), arguments: args)
    }
    
    /// Submit scripts to query the blockchain.
    /// - parameters:
    ///     - signers: A list of `FlowSigner` to sign the transaction
    /// - returns: Future<`Flow.ScriptResponse`, Error>.
    func query(@Flow.TransactionBuilder builder: () -> [Flow.TransactionBuild]) async throws -> Flow.ScriptResponse {
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
        return try await query(script: script.text, args: args)
    }
    
}
