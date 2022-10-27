//
//  File.swift
//
//
//  Created by lmcmz on 28/8/21.
//

import Foundation

public struct FCLResponse: Codable {
    public let address: String?
}

extension FCL {
    public struct Response: Decodable {
        let fType: String?
        let fVsn: String?
        let status: Status
        var updates: Service?
        var local: Service?
        var data: AuthnData?
        let reason: String?
        let compositeSignature: AuthnData?
        var authorizationUpdates: Service?

        enum CodingKeys: String, CodingKey {
            case fType
            case fVsn
            case status
            case updates
            case local
            case data
            case reason
            case compositeSignature
            case authorizationUpdates
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            fType = try? container.decode(String.self, forKey: .fType)
            fVsn = try? container.decode(String.self, forKey: .fVsn)
            status = try container.decode(Status.self, forKey: .status)
            updates = try? container.decode(Service.self, forKey: .updates)
            authorizationUpdates = try? container.decode(Service.self, forKey: .authorizationUpdates)
            do {
                local = try container.decode(Service.self, forKey: .local)
            } catch {
                let locals = try? container.decode([Service].self, forKey: .local)
                local = locals?.first
            }

            do {
                data = try container.decode(AuthnData.self, forKey: .data)
            } catch {
                let datas = try? container.decode([AuthnData].self, forKey: .data)
                data = datas?.first
            }
            reason = try? container.decode(String.self, forKey: .reason)
            compositeSignature = try? container.decode(AuthnData.self, forKey: .compositeSignature)
        }
        
        internal init(fType: String? = nil, fVsn: String? = nil, status: FCL.Status, updates: FCL.Service? = nil, local: FCL.Service? = nil, data: FCL.AuthnData? = nil, reason: String? = nil, compositeSignature: FCL.AuthnData? = nil, authorizationUpdates: FCL.Service? = nil) {
            self.fType = fType
            self.fVsn = fVsn
            self.status = status
            self.updates = updates
            self.local = local
            self.data = data
            self.reason = reason
            self.compositeSignature = compositeSignature
            self.authorizationUpdates = authorizationUpdates
        }
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
        let keyId: Int?
    }

    enum Status: String, Codable {
        case pending = "PENDING"
        case approved = "APPROVED"
        case declined = "DECLINED"
    }

    struct Service: Decodable {
        var fType: String?
        var fVsn: String?
        var type: ServiceType?
        var method: FCL.ServiceMethod?
        var endpoint: URL?
        var uid: String?
        var id: String?
        var identity: Identity?
        var provider: ServiceProvider?
        var params: [String: String]?
        var data: FCLDataResponse?

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
            case data
        }
        
        internal init(fType: String? = nil, fVsn: String? = nil, type: FCL.ServiceType? = nil, method: FCL.ServiceMethod? = nil, endpoint: URL? = nil, uid: String? = nil, id: String? = nil, identity: FCL.Identity? = nil, provider: FCL.ServiceProvider? = nil, params: [String : String]? = nil, data: FCL.FCLDataResponse? = nil) {
            self.fType = fType
            self.fVsn = fVsn
            self.type = type
            self.method = method
            self.endpoint = endpoint
            self.uid = uid
            self.id = id
            self.identity = identity
            self.provider = provider
            self.params = params
            self.data = data
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
            type = try? container.decode(ServiceType.self, forKey: .type)
            method = try? container.decode(FCL.ServiceMethod.self, forKey: .method)
            endpoint = try? container.decode(URL.self, forKey: .endpoint)
            uid = try? container.decode(String.self, forKey: .uid)
            id = try? container.decode(String.self, forKey: .id)
            identity = try? container.decode(Identity.self, forKey: .identity)
            provider = try? container.decode(ServiceProvider.self, forKey: .provider)
            data = try? container.decode(FCLDataResponse.self, forKey: .data)
        }
    }

    struct FCLDataResponse: Decodable {
        let fType: String
        let fVsn: String
        let nonce: String?
        let address: String?
        let email: FCLEmail?
        let signatures: [AuthnData]?

        struct FCLEmail: Decodable {
            let email: String
            let email_verified: Bool
        }
    }

    struct Identity: Decodable {
        public let address: String
        let keyId: Int?
    }

    struct ServiceProvider: Decodable {
        public let fType: String?
        public let fVsn: String?
        public let address: String
        public let name: String
    }

    public enum ServiceType: String, Decodable {
        case authn
        case authz
        case preAuthz = "pre-authz"
        case userSignature = "user-signature"
        case backChannel = "back-channel-rpc"
        case localView = "local-view"
        case openID = "open-id"
        case accountProof = "account-proof"
        case unknow
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

}
