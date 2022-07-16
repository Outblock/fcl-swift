//
//  File.swift
//  File
//
//  Created by lmcmz on 4/10/21.
//

import Foundation
import Flow

public enum FCLProvider: Equatable, Hashable {
    case dapper
    case blocto
    case custom(FCLWalletProvider)

    func endpoint(chainId: Flow.ChainID) -> URL {
        switch self {
        case .dapper:
            return chainId == .mainnet ? URL(string: "https://dapper-http-post.vercel.app/api/authn")! :
            // Do not know if dapper wallet has testnet url, use mainnet instead here
            URL(string: "https://dapper-http-post.vercel.app/api/authn")!
        case .blocto:
            return chainId == .mainnet ? URL(string: "https://flow-wallet.blocto.app/api/flow/authn")! :
            URL(string: "https://flow-wallet-testnet.blocto.app/api/flow/authn")!
        case .custom(let fclWalletProvider):
            return fclWalletProvider.endpoint
        }
    }
    
    func provider(chainId: Flow.ChainID) -> FCLWalletProvider {
        switch self {
        case .dapper:
            return FCLWalletProvider(id: "dapper",
                                     name: "Dapper",
                                     method: .httpPost,
                                     endpoint: endpoint(chainId: chainId))
        case .blocto:
            return FCLWalletProvider(id: "blocto",
                                     name: "Blocto",
                                     method: .httpPost,
                                     endpoint: endpoint(chainId: chainId))
        case let .custom(provider):
            return provider
        }
    }
    
    public func hash(into hasher: inout Hasher) {
//        hash(into: &endpoint(chainId: .mainnet).absoluteString)
//        hash(into: &endpoint(chainId: .testnet).absoluteString)
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

    public init(id: String, name: String, method: FCLServiceMethod, endpoint: URL) {
        self.id = id
        self.name = name
        self.method = method
        self.endpoint = endpoint
    }
}

public enum FCLServiceMethod: String, Decodable {
    case httpPost = "HTTP/POST"
    case httpGet = "HTTP/GET"
    case iframe = "VIEW/IFRAME"
    case iframeRPC = "IFRAME/RPC"
    case data = "DATA"

    var http: HTTPMethod? {
        switch self {
        case .httpGet:
            return .GET
        case .httpPost:
            return .POST
        default:
            return nil
        }
    }
}

internal enum HTTPMethod {
    case GET
    case POST
}
