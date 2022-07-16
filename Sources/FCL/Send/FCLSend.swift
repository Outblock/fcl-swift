//
//  File.swift
//
//
//  Created by lmcmz on 3/11/21.
//

import Combine
import Flow
import Foundation

public extension FCL {
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
            case .getAccount:
                ix.tag = .getAccount
            case .getBlock:
                ix.tag = .getBlock
            }
        }

        ix.status = .ok
        return ix
    }
}

public extension FCL {
    enum Build {
        case script(String)
        case transaction(String)
        case args([Flow.Cadence.FValue])
        case limit(Int)

        case getAccount(String)
        case getBlock(String)
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
