//
//  File.swift
//  File
//
//  Created by lmcmz on 4/10/21.
//

import Flow
import Foundation

extension FCL {
    public enum Provider: Equatable, Hashable {
        case dapper
        case blocto
        case lilico
        case custom(FCL.WalletProvider)

        var supportNetwork: [Flow.ChainID] {
            switch self {
            case .dapper:
                return [.mainnet]
            case .blocto:
                return [.mainnet, .testnet]
            case .lilico:
                return [.mainnet, .testnet]
            case let .custom(provider):
                return provider.supportNetwork
            }
        }

        func endpoint(chainId: Flow.ChainID) -> URL {
            switch self {
            case .dapper:
                return chainId == .mainnet ? URL(string: "https://dapper-http-post.vercel.app/api/flow/authn")! :
                    // Do not know if dapper wallet has testnet url, use mainnet instead here
                    URL(string: "https://dapper-http-post.vercel.app/api/authn")!
            case .blocto:
                return chainId == .mainnet ? URL(string: "https://flow-wallet.blocto.app/api/flow/authn")! :
                    URL(string: "https://flow-wallet-testnet.blocto.app/api/flow/authn")!
            case .lilico:
                return URL(string: "https://link.lilico.app")!
            case let .custom(fclWalletProvider):
                return fclWalletProvider.endpoint
            }
        }

        func provider(chainId: Flow.ChainID) -> FCL.WalletProvider {
            switch self {
            case .dapper:
                return .init(id: "dapper",
                             name: "Dapper",
                             method: .httpPost,
                             endpoint: endpoint(chainId: chainId),
                             supportNetwork: supportNetwork)
            case .blocto:
                return .init(id: "blocto",
                             name: "Blocto",
                             method: .httpPost,
                             endpoint: endpoint(chainId: chainId),
                             supportNetwork: supportNetwork)
            case .lilico:
                return .init(id: "lilico",
                             name: "lilico",
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
    }

    public struct WalletProvider: Equatable {
        public let id: String
        public let name: String
        public let method: FCL.ServiceMethod
        public let endpoint: URL
        public let supportNetwork: [Flow.ChainID]
        
        public init(id: String, name: String, method: FCL.ServiceMethod, endpoint: URL, supportNetwork: [Flow.ChainID]) {
            self.id = id
            self.name = name
            self.method = method
            self.endpoint = endpoint
            self.supportNetwork = supportNetwork
        }
    }

    public enum ServiceMethod: String, Decodable {
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
//    func execService(url: URL) async throws -> FCL.Response
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
    
//    func execService(url: URL) async throws -> FCL.Response {
//        return try await execService(url: url, method: .authn, request: "authn")
//    }

//    func execService<T: Encodable>(url: URL, request: T? = nil) async throws -> FCL.Response {
//        return try await execService(url: url, request: request)
//    }
}


internal enum HTTPMethod {
    case GET
    case POST
}
