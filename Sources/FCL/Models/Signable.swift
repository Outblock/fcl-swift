//
//  File.swift
//  File
//
//  Created by lmcmz on 6/10/21.
//

import BigInt
import Combine
import Flow
import Foundation

struct Signable: Encodable {
    let fType: String = "Signable"
    let fVsn: String = "1.0.1"
    let data: [String: String] = [String: String]()
    let message: String
    let keyId: Int?
    let addr: String?
    let roles: Role
    let cadence: String?
    let args: [String]
    var interaction: Interaction = Interaction()

    enum CodingKeys: String, CodingKey {
        case fType = "f_type"
        case fVsn = "f_vsn"
        case roles, data, message, keyId, addr, cadence, args, interaction, voucher
    }

    var voucher: Voucher {
        let insideSigners: [Singature] = findInsideSigners(ix: interaction).compactMap { id in
            guard let account = interaction.accounts[id] else { return nil }
            return Singature(address: account.addr,
                             keyId: account.keyID,
                             sig: account.signature)
        }

        let outsideSigners: [Singature] = findOutsideSigners(ix: interaction).compactMap { id in
            guard let account = interaction.accounts[id] else { return nil }
            return Singature(address: account.addr,
                             keyId: account.keyID,
                             sig: account.signature)
        }

        return Voucher(cadence: interaction.message.cadence,
                       refBlock: interaction.message.refBlock,
                       computeLimit: interaction.message.computeLimit,
                       arguments: interaction.message.arguments,
                       proposalKey: interaction.createProposalKey(),
                       payer: interaction.accounts[interaction.payer ?? ""]?.addr,
                       authorizers: interaction.authorizations
                           .compactMap { cid in interaction.accounts[cid]?.addr }
                           .uniqued(),
                       payloadSigs: insideSigners,
                       envelopeSigs: outsideSigners)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fType, forKey: .fType)
        try container.encode(fVsn, forKey: .fVsn)
        try container.encode(data, forKey: .data)
        try container.encode(message, forKey: .message)
        try container.encode(keyId, forKey: .keyId)
        try container.encode(roles, forKey: .roles)
        try container.encode(cadence, forKey: .cadence)
        try container.encode(addr, forKey: .addr)
        try container.encode(args, forKey: .args)
        try container.encode(interaction, forKey: .interaction)
        try container.encode(voucher, forKey: .voucher)
    }
}

struct PreSignable: Encodable {
    let fType: String = "PreSignable"
    let fVsn: String = "1.0.1"
    let roles: Role
    let cadence: String
    var args: [String] = []
    let data: [String: String] = [String: String]()
    var interaction: Interaction = Interaction()

    var voucher: Voucher {
        let insideSigners: [Singature] = findInsideSigners(ix: interaction).compactMap { id in
            guard let account = interaction.accounts[id] else { return nil }
            return Singature(address: account.addr,
                             keyId: account.keyID,
                             sig: account.signature)
        }

        let outsideSigners: [Singature] = findOutsideSigners(ix: interaction).compactMap { id in
            guard let account = interaction.accounts[id] else { return nil }
            return Singature(address: account.addr,
                             keyId: account.keyID,
                             sig: account.signature)
        }

        return Voucher(cadence: interaction.message.cadence,
                       refBlock: interaction.message.refBlock,
                       computeLimit: interaction.message.computeLimit,
                       arguments: interaction.message.arguments,
                       proposalKey: interaction.createProposalKey(),
                       payer: interaction.payer,
                       authorizers: interaction.authorizations
                           .compactMap { cid in interaction.accounts[cid]?.addr }
                           .uniqued(),
                       payloadSigs: insideSigners,
                       envelopeSigs: outsideSigners)
    }

    enum CodingKeys: String, CodingKey {
        case fType = "f_type"
        case fVsn = "f_vsn"
        case roles, cadence, args, interaction
        case voucher
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fType, forKey: .fType)
        try container.encode(fVsn, forKey: .fVsn)
        try container.encode(roles, forKey: .roles)
        try container.encode(cadence, forKey: .cadence)
        try container.encode(args, forKey: .args)
        try container.encode(interaction, forKey: .interaction)
        try container.encode(voucher, forKey: .voucher)
    }
}

struct Interaction: Encodable {
    var tag: String = "UNKNOWN"
    var assigns: [String: String] = [String: String]()
    var status: String = "OK"
    var reason: String?
    var accounts: [String: SignableUser] = [String: SignableUser]()
    var params: [String: String] = [String: String]()
    var arguments: [String: String] = [String: String]()
    var message: Message = Message()
    var proposer: String?
    var authorizations: [String] = [String]()
    var payer: String?
    var events: Events = Events()
    var transaction: Id = Id()
    var block: Block = Block()
    var account: Account = Account()
    var collection: Id = Id()

    func createProposalKey() -> ProposalKey {
        guard let proposer = proposer,
            let account = accounts[proposer] else {
            return ProposalKey()
        }

        return ProposalKey(address: account.addr,
                           keyID: account.keyID,
                           sequenceNum: account.sequenceNum)
    }

    func createFlowProposalKey() -> Flow.TransactionProposalKey? {
        guard let proposer = proposer,
            var account = accounts[proposer],
            let address = account.addr,
            let keyID = account.keyID else {
            return nil
        }

        let flowAddress = Flow.Address(hex: address)

        if account.sequenceNum == nil {
            guard let accountData = try? flow.accessAPI.getAccountAtLatestBlock(address: flowAddress).wait() else {
                return nil
            }
//            accounts[proposer]?.sequenceNum = account.keys[keyID].sequenceNumber
            account.sequenceNum = accountData.keys[keyID].sequenceNumber
        }

        return Flow.TransactionProposalKey(address: Flow.Address(hex: address),
                                           keyIndex: keyID,
                                           sequenceNumber: BigUInt(account.sequenceNum ?? 0))
    }
}

struct Block: Encodable {
    var id: String?
    var height: Int64?
    var isSealed: Bool?
}

struct Account: Encodable {
    var addr: String?
}

struct Id: Encodable {
    var id: String?
}

struct Events: Encodable {
    var eventType: String?
    var start: String?
    var end: String?
    var blockIDS: [String] = []

    enum CodingKeys: String, CodingKey {
        case eventType, start, end
        case blockIDS = "blockIds"
    }
}

struct Message: Encodable {
    var cadence: String?
    var refBlock: String?
    var computeLimit: Int?
    var proposer: String?
    var payer: String?
    var authorizations: [String] = []
    var params: [String] = []
    var arguments: [String] = []
}

struct Voucher: Encodable {
    let cadence: String?
    let refBlock: String?
    let computeLimit: Int?
    let arguments: [String]
    let proposalKey: ProposalKey
    var payer: String?
    let authorizers: [String]?
    let payloadSigs: [Singature]?
    let envelopeSigs: [Singature]?
}

struct Accounts: Encodable {
    let currentUser: SignableUser

    enum CodingKeys: String, CodingKey {
        case currentUser = "CURRENT_USER"
    }
}

struct Singature: Encodable {
    let address: String?
    let keyId: Int?
    let sig: String?
}

// MARK: - CurrentUser

struct SignableUser: Encodable {
    var kind: String?
    var tempID: String?
    var addr: String?
    var signature: String?
    var keyID: Int?
    var sequenceNum: Int?
//    var signingFunction: Int?
    let role: Role

    var signingFunction: ((Data) -> AnyPublisher<AuthnResponse, Error>)?

    enum CodingKeys: String, CodingKey {
        case kind
        case tempID = "tempId"
        case addr
        case keyID = "keyId"
        case sequenceNum, signature, signingFunction, role
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        try container.encode(tempID, forKey: .tempID)
        try container.encode(addr, forKey: .addr)
        try container.encode(signature, forKey: .signature)
        try container.encode(keyID, forKey: .keyID)
        try container.encode(sequenceNum, forKey: .sequenceNum)
        try container.encode(role, forKey: .role)
    }

//    func signingFunction(id: String) -> AnyPublisher<String, Error> {
//    }
}

struct ProposalKey: Encodable {
    var address: String?
    var keyID: Int?
    var sequenceNum: Int?

    enum CodingKeys: String, CodingKey {
        case address
        case keyID = "keyId"
        case sequenceNum
    }
}

struct Role: Encodable {
    let proposer, authorizer, payer: Bool
    let param: Bool?
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
