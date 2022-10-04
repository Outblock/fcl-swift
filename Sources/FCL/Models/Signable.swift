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

struct Signable: Codable {
    let fType: String = "Signable"
    let fVsn: String = "1.0.1"
    let data = [String: String]()
    let message: String
    let keyId: Int?
    let addr: String?
    let roles: Role
    let cadence: String?
    let args: [Flow.Argument]
    var interaction = Interaction()

    enum CodingKeys: String, CodingKey {
        case fType = "f_type"
        case fVsn = "f_vsn"
        case roles, data, message, keyId, addr, cadence, args, interaction, voucher
    }

    var voucher: Voucher {
        let insideSigners: [Singature] = interaction.findInsideSigners.compactMap { id in
            guard let account = interaction.accounts[id] else { return nil }
            return Singature(address: account.addr?.sansPrefix(),
                             keyId: account.keyID,
                             sig: account.signature)
        }

        let outsideSigners: [Singature] = interaction.findOutsideSigners.compactMap { id in
            guard let account = interaction.accounts[id] else { return nil }
            return Singature(address: account.addr?.sansPrefix(),
                             keyId: account.keyID,
                             sig: account.signature)
        }

        return Voucher(cadence: interaction.message.cadence,
                       refBlock: interaction.message.refBlock,
                       computeLimit: interaction.message.computeLimit,
                       arguments: interaction.message.arguments.compactMap { tempId in
                           interaction.arguments[tempId]?.asArgument
                       },
                       proposalKey: interaction.createProposalKey(),
                       payer: interaction.accounts[interaction.payer ?? ""]?.addr?.sansPrefix(),
                       authorizers: interaction.authorizations
                           .compactMap { cid in interaction.accounts[cid]?.addr?.sansPrefix() }
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

struct PreSignable: Codable {
    let fType: String = "PreSignable"
    let fVsn: String = "1.0.1"
    let roles: Role
    let cadence: String
    var args: [Flow.Argument] = []
    let data = [String: String]()
    var interaction = Interaction()

    var voucher: Voucher {
        let insideSigners: [Singature] = interaction.findInsideSigners.compactMap { id in
            guard let account = interaction.accounts[id] else { return nil }
            return Singature(address: account.addr,
                             keyId: account.keyID,
                             sig: account.signature)
        }

        let outsideSigners: [Singature] = interaction.findOutsideSigners.compactMap { id in
            guard let account = interaction.accounts[id] else { return nil }
            return Singature(address: account.addr,
                             keyId: account.keyID,
                             sig: account.signature)
        }

        return Voucher(cadence: interaction.message.cadence,
                       refBlock: interaction.message.refBlock,
                       computeLimit: interaction.message.computeLimit,
                       arguments: interaction.message.arguments.compactMap { tempId in
                           interaction.arguments[tempId]?.asArgument
                       },
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

struct Argument: Codable {
    var kind: String
    var tempId: String
    var value: Flow.Cadence.FValue
    var asArgument: Flow.Argument
    var xform: Xform
}

struct Xform: Codable {
    var label: String
}

extension Flow.Argument {
    func toFCLArgument() -> Argument {
        func randomString(length: Int) -> String {
            let letters = "abcdefghijklmnopqrstuvwxyz0123456789"
            return String((0 ..< length).map { _ in letters.randomElement()! })
        }

        return Argument(kind: "ARGUMENT",
                        tempId: randomString(length: 10),
                        value: value,
                        asArgument: self,
                        xform: Xform(label: type.rawValue))
    }
}

struct Interaction: Codable {
    var tag: Tag = .unknown
    var assigns = [String: String]()
    var status: Status = .ok
    var reason: String?
    var accounts = [String: SignableUser]()
    var params = [String: String]()
    var arguments = [String: Argument]()
    var message = Message()
    var proposer: String?
    var authorizations = [String]()
    var payer: String?
    var events = Events()
    var transaction = Id()
    var block = Block()
    var account = Account()
    var collection = Id()

    enum Status: String, CaseIterable, Codable {
        case ok = "OK"
        case bad = "BAD"
    }

    enum Tag: String, CaseIterable, Codable {
        case unknown = "UNKNOWN"
        case script = "SCRIPT"
        case transaction = "TRANSACTION"
        case getTransactionStatus = "GET_TRANSACTION_STATUS"
        case getAccount = "GET_ACCOUNT"
        case getEvents = "GET_EVENTS"
        case getLatestBlock = "GET_LATEST_BLOCK"
        case ping = "PING"
        case getTransaction = "GET_TRANSACTION"
        case getBlockById = "GET_BLOCK_BY_ID"
        case getBlockByHeight = "GET_BLOCK_BY_HEIGHT"
        case getBlock = "GET_BLOCK"
        case getBlockHeader = "GET_BLOCK_HEADER"
        case getCollection = "GET_COLLECTION"
    }

    var isUnknown: Bool { `is`(.unknown) }
    var isScript: Bool { `is`(.script) }
    var isTransaction: Bool { `is`(.transaction) }

    func `is`(_ tag: Tag) -> Bool {
        self.tag == tag
    }

    @discardableResult
    mutating func setTag(_ tag: Tag) -> Self {
        self.tag = tag
        return self
    }

    var findInsideSigners: [String] {
        // Inside Signers Are: (authorizers + proposer) - payer
        var inside = Set(authorizations)
        if let proposer = proposer {
            inside.insert(proposer)
        }
        if let payer = payer {
            inside.remove(payer)
        }
        return Array(inside)
    }

    var findOutsideSigners: [String] {
        // Outside Signers Are: (payer)
        guard let payer = payer else {
            return []
        }
        let outside = Set([payer])
        return Array(outside)
    }

    func createProposalKey() -> ProposalKey {
        guard let proposer = proposer,
              let account = accounts[proposer]
        else {
            return ProposalKey()
        }

        return ProposalKey(address: account.addr?.sansPrefix(),
                           keyID: account.keyID,
                           sequenceNum: account.sequenceNum)
    }

    func createFlowProposalKey() async throws -> Flow.TransactionProposalKey {
        guard let proposer = proposer,
              var account = accounts[proposer],
              let address = account.addr,
              let keyID = account.keyID
        else {
            throw FCLError.invaildProposer
        }

        let flowAddress = Flow.Address(hex: address)

        if account.sequenceNum == nil {
            let accountData = try await flow.accessAPI.getAccountAtLatestBlock(address: flowAddress)
            account.sequenceNum = Int(accountData.keys[keyID].sequenceNumber)
            let key = Flow.TransactionProposalKey(address: Flow.Address(hex: address),
                                                  keyIndex: keyID,
                                                  sequenceNumber: Int64(account.sequenceNum ?? 0))
            return key
        } else {
            let key = Flow.TransactionProposalKey(address: Flow.Address(hex: address),
                                                  keyIndex: keyID,
                                                  sequenceNumber: Int64(account.sequenceNum ?? 0))
            return key
        }
    }

    func buildPreSignable(role: Role) -> PreSignable {
        return PreSignable(roles: role,
                           cadence: message.cadence ?? "",
                           args: message.arguments.compactMap { tempId in arguments[tempId]?.asArgument },
                           interaction: self)
    }

    func toFlowTransaction() async throws -> Flow.Transaction {
        let proposalKey = try await createFlowProposalKey()

        guard let payerAccount = payer,
              let payerAddress = accounts[payerAccount]?.addr
        else {
            throw FCLError.missingPayer
        }

        var tx = Flow.Transaction(script: Flow.Script(text: message.cadence ?? ""),
                                  arguments: message.arguments.compactMap { tempId in arguments[tempId]?.asArgument },
                                  referenceBlockId: Flow.ID(hex: message.refBlock ?? ""),
                                  gasLimit: BigUInt(message.computeLimit ?? 100),
                                  proposalKey: proposalKey,
                                  payer: Flow.Address(hex: payerAddress),
                                  authorizers: authorizations
                                      .compactMap { cid in accounts[cid]?.addr }
                                      .uniqued()
                                      .compactMap { Flow.Address(hex: $0) })

        let insideSigners = findInsideSigners
        insideSigners.forEach { address in
            if let account = accounts[address],
               let address = account.addr,
               let keyId = account.keyID,
               let signature = account.signature
            {
                tx.addPayloadSignature(address: Flow.Address(hex: address),
                                       keyIndex: keyId,
                                       signature: Data(signature.hexValue))
            }
        }

        let outsideSigners = findOutsideSigners

        outsideSigners.forEach { address in
            if let account = accounts[address],
               let address = account.addr,
               let keyId = account.keyID,
               let signature = account.signature
            {
                tx.addEnvelopeSignature(address: Flow.Address(hex: address),
                                        keyIndex: keyId,
                                        signature: Data(signature.hexValue))
            }
        }
        return tx
    }
}

struct Block: Codable {
    var id: String?
    var height: Int64?
    var isSealed: Bool?
}

struct Account: Codable {
    var addr: String?
}

struct Id: Encodable {
    var id: String?
}

struct Events: Codable {
    var eventType: String?
    var start: String?
    var end: String?
    var blockIDS: [String] = []

    enum CodingKeys: String, CodingKey {
        case eventType, start, end
        case blockIDS = "blockIds"
    }
}

struct Message: Codable {
    var cadence: String?
    var refBlock: String?
    var computeLimit: Int?
    var proposer: String?
    var payer: String?
    var authorizations: [String] = []
    var params: [String] = []
    var arguments: [String] = []
}

struct Voucher: Codable {
    let cadence: String?
    let refBlock: String?
    let computeLimit: Int?
    let arguments: [Flow.Argument]
    let proposalKey: ProposalKey
    var payer: String?
    let authorizers: [String]?
    let payloadSigs: [Singature]?
    let envelopeSigs: [Singature]?
}

struct Accounts: Codable {
    let currentUser: SignableUser

    enum CodingKeys: String, CodingKey {
        case currentUser = "CURRENT_USER"
    }
}

struct Singature: Codable {
    let address: String?
    let keyId: Int?
    let sig: String?
}

// MARK: - CurrentUser

// protocol SignableUserFetchSignature {
//    func signingFunction(service: Service, data: Data) async throws -> AuthnResponse
// }

typealias FCLSigningFunction<T:Encodable> = ((T) -> Task<FCL.Response, Error>)?

struct SignableUser: Codable {
//    func signingFunction(service: Service, data: Data) async throws -> AuthnResponse {
//
//        return try await fcl.api.execHttpPost(service: service, data: data)
//    }

    var kind: String?
    var tempID: String?
    var addr: String?
    var signature: String?
    var keyID: Int?
    var sequenceNum: Int?
    //    var signingFunction: Int?
    var role: Role

    var signingFunction: FCLSigningFunction<Signable>

    enum CodingKeys: String, CodingKey {
        case kind
        case tempID = "tempId"
        case addr
        case keyID = "keyId"
        case sequenceNum, signature, role
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
}

struct ProposalKey: Codable {
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
    var proposer: Bool = false
    var authorizer: Bool = false
    var payer: Bool = false
    var param: Bool?

    mutating func merge(role: Role) {
        proposer = proposer || role.proposer
        authorizer = authorizer || role.authorizer
        payer = payer || role.payer
    }
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
