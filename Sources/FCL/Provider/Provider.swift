//
//  File.swift
//  File
//
//  Created by lmcmz on 4/10/21.
//

import Flow
import Foundation

public enum FCLProvider: Equatable, Hashable {
    case dapper
    case blocto
    case lilico
    case custom(FCLWalletProvider)

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

    func provider(chainId: Flow.ChainID) -> FCLWalletProvider {
        switch self {
        case .dapper:
            return FCLWalletProvider(id: "dapper",
                                     name: "Dapper",
                                     method: .httpPost,
                                     endpoint: endpoint(chainId: chainId),
                                     supportNetwork: supportNetwork)
        case .blocto:
            return FCLWalletProvider(id: "blocto",
                                     name: "Blocto",
                                     method: .httpPost,
                                     endpoint: endpoint(chainId: chainId),
                                     supportNetwork: supportNetwork)
        case .lilico:
            return FCLWalletProvider(id: "lilico",
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

    public static func == (lhs: FCLProvider, rhs: FCLProvider) -> Bool {
        return lhs.provider(chainId: flow.chainID) == rhs.provider(chainId: flow.chainID)
    }
}

public struct FCLWalletProvider: Equatable {
    public let id: String
    public let name: String
    public let method: FCLServiceMethod
    public let endpoint: URL
    public let supportNetwork: [Flow.ChainID]
}

public enum FCLServiceMethod: String, Decodable {
    case httpPost = "HTTP/POST"
    case walletConnect = "WC/RPC"
    
    var provider: FCLStrategy {
        switch self {
        case .httpPost:
            return FCL.HTTPProvider()
        case .walletConnect:
            return FCL.WalletConnectProvider()
        }
    }
}

protocol FCLStrategy {
    func execService(service: FCL.Service, data: Data?) async throws -> FCL.Response
    func execService(url: URL, data: Data?) async throws -> FCL.Response
}

extension FCLStrategy {
    
    func execService(service: FCL.Service, data: Data? = nil) async throws -> FCL.Response {
        guard let url = service.endpoint, let param = service.params else {
            throw FCLError.generic
        }
        
        guard let fullURL = buildURL(url: url, params: param) else {
            throw FCLError.invaildURL
        }

        return try await execService(url: fullURL, data: data)
    }
    
    func execService(url: URL, data: Data? = nil) async throws -> FCL.Response {
        return try await execService(url: url, data: data)
    }
}


internal enum HTTPMethod {
    case GET
    case POST
}
