//
//  File.swift
//
//
//  Created by lmcmz on 29/8/21.
//

import Foundation

public enum FCLError: String, Error, LocalizedError {
    case generic
    case invaildURL
    case invalidSession
    case declined
    case invalidResponse
    case decodeFailure
    case unauthenticated
    case missingPreAuthz
    case missingPayer
    case encodeFailure
    case convertToTxFailure
    case invaildProposer
    case fetchAccountFailure

    public var errorDescription: String? {
        return rawValue
    }
}
