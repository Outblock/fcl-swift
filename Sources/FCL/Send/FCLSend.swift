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
    func send(_ builds: [Build]) -> Future<String, Error> {
        let ix = prepare(ix: Interaction(), builder: builds)

        let resolvers: [Resolver] = [
            CadenceResolver(),
            AccountsResolver(),
            RefBlockResolver(),
            SequenceNumberResolver(),
            SignatureResolver(),
        ]

        return pipe(ix: ix, resolvers: resolvers)
            .flatMap { ix in self.sendIX(ix: ix) }
            .map { $0.hex }.asFuture()
    }

    func send(@FCL.Builder builder: () -> [Build]) -> Future<String, Error> {
        return send(builder())
    }

    internal func prepare(ix: Interaction, builder: [Build]) -> Interaction {
        var newIX = ix

        builder.forEach { build in
            switch build {
            case let .script(script):
                newIX.tag = .script
                newIX.message.cadence = script
            case let .args(args):
                let fclArgs = args.compactMap { Flow.Argument(value: $0) }.toFCLArguments()
                newIX.message.arguments = Array(fclArgs.map { $0.0 })
                newIX.arguments = fclArgs.reduce(into: [:]) { $0[$1.0] = $1.1 }
            case let .transaction(script):
                newIX.tag = .transaction
                newIX.message.cadence = script
            case let .limit(gasLimit):
                newIX.message.computeLimit = gasLimit
            case let .getAccount(account):
                newIX.tag = .getAccount
            case .getBlock:
                newIX.tag = .getBlock
            }
        }

        newIX.status = .ok

        return newIX
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
