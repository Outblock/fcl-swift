//
//  File.swift
//  File
//
//  Created by lmcmz on 4/10/21.
//

import Flow
import Foundation

public extension FCL {
    enum Provider: Equatable, Hashable, CaseIterable {
        case dapper
        case dapperSC
        case blocto
        case lilico
        case custom(FCL.WalletProvider)

        public static var allCases: [FCL.Provider] = [.dapper, .dapperSC, .lilico, .blocto]

        public static func getEnvCases(env: Flow.ChainID = fcl.currentEnv) -> [FCL.Provider] {
            allCases.filter { $0.supportNetwork.contains(env) }
        }

        public var supportAutoConnect: Bool {
            provider(chainId: .mainnet).supportAutoConnect
        }

        public var supportNetwork: [Flow.ChainID] {
            switch self {
            case .dapper:
                return [.mainnet]
            case .dapperSC:
                return [.testnet]
            case .blocto:
                return [.mainnet, .testnet]
            case .lilico:
                return [.mainnet, .testnet]
            case let .custom(provider):
                return provider.supportNetwork
            }
        }

        public func endpoint(chainId: Flow.ChainID = fcl.currentEnv) -> String {
            switch self {
            case .dapper:
                return "https://dapper-http-post.vercel.app/api/flow/authn"
            case .dapperSC:
                return "dapper-pro://"
            case .blocto:
                return chainId == .mainnet ? URL(string: "https://flow-wallet.blocto.app/api/flow/authn")!.absoluteString :
                    URL(string: "https://flow-wallet-testnet.blocto.app/api/flow/authn")!.absoluteString
            case .lilico:
                return URL(string: "https://link.lilico.app")!.absoluteString
            case let .custom(fclWalletProvider):
                return fclWalletProvider.endpoint
            }
        }

        public var id: String {
            provider(chainId: .mainnet).id
        }

        public var name: String {
            provider(chainId: .mainnet).name
        }

        public func provider(chainId: Flow.ChainID = fcl.currentEnv) -> FCL.WalletProvider {
            switch self {
            case .dapper:
                return .init(id: "dapper",
                             name: "Dapper",
                             logo: URL(string: "https://raw.githubusercontent.com/Outblock/fcl-swift/main/Assets/dapper/logo.jpeg")!,
                             method: .httpPost,
                             endpoint: endpoint(chainId: chainId),
                             supportNetwork: supportNetwork)
            case .dapperSC:
                return .init(id: "dapper-sc",
                             name: "Dapper SC",
                             logo: URL(string: "https://raw.githubusercontent.com/Outblock/fcl-swift/main/Assets/dapper-sc/logo.png")!,
                             method: .walletConnect,
                             endpoint: endpoint(chainId: chainId),
                             supportNetwork: supportNetwork)
            case .blocto:
                return .init(id: "blocto",
                             name: "Blocto",
                             logo: URL(string: "https://raw.githubusercontent.com/Outblock/fcl-swift/main/Assets/blocto/logo.jpg")!,
                             method: .httpPost,
                             endpoint: endpoint(chainId: chainId),
                             supportNetwork: supportNetwork)
            case .lilico:
                return .init(id: "lilico",
                             name: "lilico",
                             logo: URL(string: "https://raw.githubusercontent.com/Outblock/fcl-swift/main/Assets/lilico/logo.png")!,
                             method: .walletConnect,
                             endpoint: endpoint(chainId: chainId),
                             supportNetwork: supportNetwork)
            case let .custom(provider):
                return provider
            }
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(endpoint(chainId: .mainnet))
            hasher.combine(endpoint(chainId: .testnet))
        }

        public static func == (lhs: Provider, rhs: Provider) -> Bool {
            return lhs.provider(chainId: flow.chainID) == rhs.provider(chainId: flow.chainID)
        }

        init?(id: String) {
            guard let item = FCL.Provider.allCases.first(where: { $0.id == id }) else {
                return nil
            }
            self = item
        }
    }

    struct WalletProvider: Equatable {
        public let id: String
        public let name: String
        public let logo: URL
        public let method: FCL.ServiceMethod
        public let endpoint: String
        public let supportNetwork: [Flow.ChainID]

        public var supportAutoConnect: Bool {
            method == .walletConnect
        }

        public init(id: String,
                    name: String,
                    logo: URL,
                    method: FCL.ServiceMethod,
                    endpoint: String,
                    supportNetwork: [Flow.ChainID])
        {
            self.id = id
            self.name = name
            self.logo = logo
            self.method = method
            self.endpoint = endpoint
            self.supportNetwork = supportNetwork
        }
    }

    enum ServiceMethod: String, Codable {
        case httpPost = "HTTP/POST"
        case walletConnect = "WC/RPC"

        var provider: FCLStrategy {
            switch self {
            case .httpPost:
                return fcl.httpProvider
            case .walletConnect:
                return fcl.wcProvider ?? FCL.WalletConnectProvider()
            }
        }
    }
}

protocol FCLStrategy {
    func execService<T: Encodable>(service: FCL.Service, request: T?) async throws -> FCL.Response
    func execService<T: Encodable>(url: URL, method: FCL.ServiceType, request: T?) async throws -> FCL.Response
}

extension FCLStrategy {
    func execService<T: Encodable>(service: FCL.Service, request: T? = nil) async throws -> FCL.Response {
        guard let url = service.endpoint, let param = service.params else {
            throw FCLError.generic
        }

        guard let fullURL = buildURL(url: url, params: param) else {
            throw FCLError.invaildURL
        }

        return try await execService(url: fullURL, method: service.type ?? .unknow, request: request)
    }
}

internal enum HTTPMethod {
    case GET
    case POST
}
