//
//  File.swift
//
//
//  Created by lmcmz on 4/9/21.
//

import Foundation

public struct PreAuthzResponse: Decodable {
    public let fType: String
    public let fVsn: String
    let status: Status
    //        let data: AuthData
}
