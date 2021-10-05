//
//  File.swift
//  File
//
//  Created by lmcmz on 6/10/21.
//

import Foundation

struct PreSignable: Encodable {
    let fType: String
    let fVsn: String
    let roles: Role
    let cadence: String
    let args: [String]
    let interaction: Interaction
    let voucher: Voucher

    enum CodingKeys: String, CodingKey {
        case fType = "f_type"
        case fVsn = "f_vsn"
        case roles, cadence, args, interaction, voucher
    }
}

struct Interaction: Encodable {
    let tag: String
    let assigns: [String: String]?
    let status: String
    @NullEncodable var reason: String?
    let accounts: Accounts
    let params, arguments: [String: String]?
    let message: Message
    let proposer: String
    let authorizations: [String]?
    let payer: String
    let events: Events
    let transaction: Id
    let block: Block
    let account: Account
    let collection: Id
}

struct Block: Encodable {
    @NullEncodable var id: String?
    @NullEncodable var height: Int64?
    @NullEncodable var isSealed: Bool?
}

struct Account: Encodable {
    @NullEncodable var addr: String?
}

struct Id: Encodable {
    @NullEncodable var id: String?
}

struct Events: Encodable {
    @NullEncodable var eventType: String?
    @NullEncodable var start: String?
    @NullEncodable var end: String?
    let blockIDS: [String]?

    enum CodingKeys: String, CodingKey {
        case eventType, start, end
        case blockIDS = "blockIds"
    }
}

struct Message: Encodable {
    let cadence, refBlock: String
    let computeLimit: Int
    @NullEncodable var proposer: String?
    @NullEncodable var payer: String?
    let authorizations, params, arguments: [String]?
}

struct Voucher: Encodable {
    let cadence, refBlock: String
    let computeLimit: Int
    let arguments: [String]
    let proposalKey: ProposalKey
    @NullEncodable var payer: String?
    let authorizers, payloadSigs: [String]?
}

struct Accounts: Encodable {
    let currentUser: CurrentUser

    enum CodingKeys: String, CodingKey {
        case currentUser = "CURRENT_USER"
    }
}

// MARK: - CurrentUser

struct CurrentUser: Encodable {
    let kind, tempID: String
    @NullEncodable var addr: String?
    @NullEncodable var signature: String?
    @NullEncodable var keyID: Int?
    @NullEncodable var sequenceNum: Int?
    @NullEncodable var signingFunction: Int?
    let role: Role

    enum CodingKeys: String, CodingKey {
        case kind
        case tempID = "tempId"
        case addr
        case keyID = "keyId"
        case sequenceNum, signature, signingFunction, role
    }
}

struct ProposalKey: Encodable {
    @NullEncodable var address: String?
    @NullEncodable var keyID: Int?
    @NullEncodable var sequenceNum: Int?

    enum CodingKeys: String, CodingKey {
        case address
        case keyID = "keyId"
        case sequenceNum
    }
}

struct Role: Encodable {
    let proposer, authorizer, payer, param: Bool
}

@propertyWrapper
struct NullEncodable<T>: Encodable where T: Encodable {
    var wrappedValue: T?

    init(wrappedValue: T?) {
        self.wrappedValue = wrappedValue
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch wrappedValue {
        case let .some(value): try container.encode(value)
        case .none: try container.encodeNil()
        }
    }
}
