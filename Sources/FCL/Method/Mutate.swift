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

public extension FCL {
    internal func pipe(ix: inout Interaction, resolvers: [Resolver]) async throws -> Interaction {
        if let resolver = resolvers.first {
            _ = try await resolver.resolve(ix: &ix)
            return try await pipe(ix: &ix, resolvers: Array(resolvers.dropFirst()))
        } else {
            return ix
        }
    }

    internal func sendIX(ix: Interaction) async throws -> Flow.ID {
        let tx = try await ix.toFlowTransaction()
        return try await flow.accessAPI.sendTransaction(transaction: tx)
    }

    func mutate(cadence: String,
                args: [Flow.Cadence.FValue],
                gasLimit: Int = 1000,
                proposer: FCLSigner? = nil,
                authorizors: [FCLSigner]? = nil,
                payers: [FCLSigner]? = nil) async throws -> Flow.ID {
        
        var list: [Build] = [.transaction(cadence), .args(args), .limit(gasLimit)]
        if let proposer {
            list.append(.proposer(proposer))
        }
        if let authorizors {
            list.append(.authorizor(authorizors))
        }
        if let payers {
            list.append(.payer(payers))
        }
        return try await send(list)
    }

    func mutate(@FCL.Builder builder: () -> [FCL.Build]) async throws -> Flow.ID {
        return try await send(builder())
    }
    
    func send(_ builds: [Build]) async throws -> Flow.ID {
        var ix = Interaction()
        _ = prepare(ix: &ix, builder: builds)

        let resolvers: [Resolver] = [
            CadenceResolver(),
            AccountsResolver(),
            RefBlockResolver(),
            SequenceNumberResolver(),
            SignatureResolver(),
        ]
        _ = try await pipe(ix: &ix, resolvers: resolvers)
        return try await sendIX(ix: ix)
    }

    func send(@FCL.Builder builder: () -> [Build]) async throws -> Flow.ID {
        return try await send(builder())
    }

    internal func prepare(ix: inout Interaction, builder: [Build]) -> Interaction {
        builder.forEach { build in
            switch build {
//            case let .script(script):
//                ix.tag = .script
//                ix.message.cadence = script
            case let .args(args):
                let fclArgs = args.compactMap { Flow.Argument(value: $0) }.toFCLArguments()
                ix.message.arguments = Array(fclArgs.map { $0.0 })
                ix.arguments = fclArgs.reduce(into: [:]) { $0[$1.0] = $1.1 }
            case let .transaction(script):
                ix.tag = .transaction
                ix.message.cadence = script
            case let .limit(gasLimit):
                ix.message.computeLimit = gasLimit
            case let .proposer(signer):
                var signableUser = signer.signableUser
                signableUser.role = Role(proposer: true)
                ix.accounts[signer.tempID] = signableUser
            case let .authorizor(signers):
                for signer in signers {
                    var signableUser = signer.signableUser
                    signableUser.role = Role(proposer: true)
                    ix.accounts[signer.tempID] = signableUser
                    let tempID = signer.tempID
                    if ix.accounts.keys.contains(tempID) {
                        ix.accounts[tempID]?.role.merge(role: Role(authorizer: true))
                    }
                }
            case let .payer(signers):
                for signer in signers {
                    var signableUser = signer.signableUser
                    signableUser.role = Role(proposer: true)
                    ix.accounts[signer.tempID] = signableUser
                    let tempID = signer.tempID
                    if ix.accounts.keys.contains(tempID) {
                        ix.accounts[tempID]?.role.merge(role: Role(payer: true))
                    }
                }
            }
        }

        ix.status = .ok
        return ix
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

public extension FCL {
    enum Build {
//        case script(String)
        case transaction(String)
        case args([Flow.Cadence.FValue])
        case limit(Int)
        case proposer(FCLSigner)
        case authorizor([FCLSigner])
        case payer([FCLSigner])
    }

    @resultBuilder
    enum Builder {
        public static func buildBlock() -> [Build] { [] }

        public static func buildArray(_ components: [[Build]]) -> [Build] {
            return components.flatMap { $0 }
        }

        public static func buildBlock(_ components: Build...) -> [Build] {
            components
        }
        
        public static func buildEither(first component: [Build]) -> [Build] {
            component
        }
        
        public static func buildEither(second component: [Build]) -> [Build] {
            component
        }
    }
}
