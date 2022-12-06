//
//  File.swift
//
//
//  Created by lmcmz on 14/9/21.
//

import Foundation

extension FCL {
    enum Constants {
        static var verifyAccountProofSignaturesCadence = """
              import FCLCrypto from 0xFCLCrypto
              pub fun main(
                  address: Address,
                  message: String,
                  keyIndices: [Int],
                  signatures: [String]
              ): Bool {
                return FCLCrypto.verifyAccountProofSignatures(address: address, message: message, keyIndices: keyIndices, signatures: signatures)
              }
        """

        static var verifyUserSignaturesCadence = """
              import FCLCrypto from 0xFCLCrypto
              pub fun main(
                  address: Address,
                  message: String,
                  keyIndices: [Int],
                  signatures: [String]
              ): Bool {
                return FCLCrypto.verifyUserSignatures(address: address, message: message, keyIndices: keyIndices, signatures: signatures)
              }
        """
    }
}
