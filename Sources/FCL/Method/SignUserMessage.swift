//
//  File.swift
//
//
//  Created by Hao Fu on 25/9/2022.
//

import Flow
import Foundation

public extension FCL {
    func verifyUserSignature(message: String, compSigs: [FCLUserSignatureResponse]) async throws -> Bool {
        guard let currentUser = currentUser, currentUser.loggedIn else {
            throw Flow.FError.unauthenticated
        }

        return try await fcl.query {
            cadence {
                FCL.Constants.verifyUserSignaturesCadence
            }

            arguments {
                [
                    .address(Flow.Address(hex: compSigs.first?.addr ?? "")),
                    .string(message.data(using: .utf8)?.hexValue ?? ""),
                    .array(compSigs.compactMap { Flow.Argument(value: .int($0.keyId)) }),
                    .array(compSigs.compactMap { Flow.Argument(value: .string($0.signature)) }),
                ]
            }
        }.decode()
    }

    func signUserMessage(message: String) async throws -> FCLUserSignatureResponse {
        guard let currentUser = currentUser, currentUser.loggedIn else {
            throw Flow.FError.unauthenticated
        }

        guard let service = serviceOfType(services: currentUser.services, type: .userSignature),
              let endpoint = service.endpoint
        else {
            throw FCLError.invaildService
        }

        struct SignableMessage: Codable {
            let message: String
        }

        guard let messageData = message.data(using: .utf8),
              let data = try? JSONEncoder().encode(SignableMessage(message: messageData.hexValue))
        else {
            throw FCLError.encodeFailure
        }
//        
//        guard let fullURL = buildURL(url: endpoint, params: service.params) else {
//            throw FCLError.invaildURL
//        }

        let model = try await fcl.getStategy().execService(service: service, request: SignableMessage(message: messageData.hexValue))
        guard let data = model.data, let signature = data.signature, let address = data.addr, let keyId = data.keyId else {
            throw FCLError.generic
        }

        return .init(addr: address, keyId: keyId, signature: signature)
    }
}
