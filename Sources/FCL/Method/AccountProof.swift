//
//  File.swift
//
//
//  Created by Hao Fu on 25/9/2022.
//

import Flow
import Foundation

public extension FCL {
    func verifyAccountProof(includeDomainTag: Bool = false) async throws -> Bool {
        guard let currentUser = currentUser, currentUser.loggedIn else {
            throw Flow.FError.unauthenticated
        }

        guard let service = serviceOfType(services: currentUser.services, type: .accountProof),
              let data = service.data,
              let address = data.address,
              let signatures = data.signatures,
              let appIdentifier = config.get(.appId),
              let nonce = config.get(.nonce)
        else {
            throw FCLError.invaildService
        }

        guard let encoded = RLP.encode([appIdentifier.data(using: .utf8), address.hexValue.data, nonce.hexValue.data]) else {
            throw FCLError.encodeFailure
        }

        let encodedTag = includeDomainTag ? Flow.DomainTag.custom("FCL-ACCOUNT-PROOF-V0.0").normalize : Data() + encoded

        return try await fcl.query {
            cadence {
                FCL.Constants.verifyAccountProofSignaturesCadence
            }

            arguments {
                [
                    .address(Flow.Address(hex: data.address ?? "")),
                    .string(encodedTag.hexValue),
                    .array(signatures.compactMap { .int($0.keyId ?? -1) }),
                    .array(signatures.compactMap { .string($0.signature ?? "") }),
                ]
            }
        }.decode()
    }
}
