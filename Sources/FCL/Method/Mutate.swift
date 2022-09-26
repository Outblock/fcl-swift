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

    func mutate(cadence: String, args: [Flow.Cadence.FValue], gasLimit: Int = 1000) async throws -> Flow.ID {
        return try await send([.script(cadence), .args(args), .limit(gasLimit)])
    }

    func mutate(@Flow.TransactionBuilder builder: () -> [Flow.TransactionBuild]) async throws -> Flow.ID {
        return try await send(builder().compactMap { $0.toFCLBuild() })
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
            case let .script(script):
                ix.tag = .script
                ix.message.cadence = script
            case let .args(args):
                let fclArgs = args.compactMap { Flow.Argument(value: $0) }.toFCLArguments()
                ix.message.arguments = Array(fclArgs.map { $0.0 })
                ix.arguments = fclArgs.reduce(into: [:]) { $0[$1.0] = $1.1 }
            case let .transaction(script):
                ix.tag = .transaction
                ix.message.cadence = script
            case let .limit(gasLimit):
                ix.message.computeLimit = gasLimit
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
        case script(String)
        case transaction(String)
        case args([Flow.Cadence.FValue])
        case limit(Int)
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
    }
}
