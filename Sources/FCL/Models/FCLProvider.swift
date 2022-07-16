//
//  File.swift
//  File
//
//  Created by lmcmz on 4/10/21.
//

import Foundation

public enum FCLProvider: Equatable {
    case dapper
    case blocto
    case custom(FCLWalletProvider)

    var provider: FCLWalletProvider {
        switch self {
        case .dapper:
            return FCLWalletProvider(id: "dapper",
                                     name: "Dapper",
                                     method: .httpPost,
                                     endpoint: URL(string: "https://dapper-http-post.vercel.app/api/authn")!)
        case .blocto:
            return FCLWalletProvider(id: "blocto",
                                     name: "Blocto",
                                     method: .httpPost,
                                     endpoint: URL(string: "https://flow-wallet.blocto.app/api/flow/authn")!)
        case let .custom(provider):
            return provider
        }
    }

    public static func == (lhs: FCLProvider, rhs: FCLProvider) -> Bool {
        return lhs.provider == rhs.provider
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
