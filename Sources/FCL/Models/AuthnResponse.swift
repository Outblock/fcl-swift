//
//  File.swift
//
//
//  Created by lmcmz on 28/8/21.
//

import Foundation

public struct FCLResponse {
    public let address: String?
}

struct AuthnResponse: Decodable {
    let fType: String?
    let fVsn: String?
    let status: Status
    var updates: Service?
    var local: Service?
    var data: AuthnData?
    let reason: String?
}

struct AuthnData: Decodable {
    let addr: String?
    let fType: String?
    let fVsn: String?
    let services: [Service]?
    let proposer: Service?
    let payer: [Service]?
    let authorization: [Service]?
    let signature: String?
}

enum Status: String, Decodable {
    case pending = "PENDING"
    case approved = "APPROVED"
    case declined = "DECLINED"
}

struct Service: Decodable {
    let fType: String?
    let fVsn: String?
    let type: FCLServiceType?
    let method: FCLServiceMethod?
    let endpoint: URL?
    let uid: String?
    let id: String?
    let identity: Identity?
    let provider: Provider?
    let params: [String: String]?

    enum CodingKeys: String, CodingKey {
        case fType
        case fVsn
        case type
        case method
        case endpoint
        case uid
        case id
        case identity
        case provider
        case params
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawValue = try? container.decode([String: ParamValue].self, forKey: .params)
        var result = [String: String]()
        rawValue?.compactMap { $0 }.forEach { key, value in
            result[key] = value.value
        }
        params = result
        fType = try? container.decode(String.self, forKey: .fType)
        fVsn = try? container.decode(String.self, forKey: .fVsn)
        type = try? container.decode(FCLServiceType.self, forKey: .type)
        method = try? container.decode(FCLServiceMethod.self, forKey: .method)
        endpoint = try? container.decode(URL.self, forKey: .endpoint)
        uid = try? container.decode(String.self, forKey: .uid)
        id = try? container.decode(String.self, forKey: .id)
        identity = try? container.decode(Identity.self, forKey: .identity)
        provider = try? container.decode(Provider.self, forKey: .provider)
    }
}

struct Identity: Decodable {
    public let address: String
    let keyId: Int?
}

struct Provider: Decodable {
    public let fType: String?
    public let fVsn: String?
    public let address: String
    public let name: String
}

public enum FCLServiceType: String, Decodable {
    case authn
    case authz
    case preAuthz = "pre-authz"
    case userSignature = "user-signature"
    case backChannel = "back-channel-rpc"
    case localView = "local-view"
    case openID = "open-id"
}

struct ParamValue: Decodable {
    var value: String

    init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer() {
            if let intVal = try? container.decode(Int.self) {
                value = String(intVal)
            } else if let doubleVal = try? container.decode(Double.self) {
                value = String(doubleVal)
            } else if let boolVal = try? container.decode(Bool.self) {
                value = String(boolVal)
            } else if let stringVal = try? container.decode(String.self) {
                value = stringVal
            } else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "the container contains nothing serialisable")
            }
        } else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Could not serialise"))
        }
    }
}
