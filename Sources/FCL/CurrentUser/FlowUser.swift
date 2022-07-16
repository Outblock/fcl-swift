//
//  File.swift
//
//
//  Created by lmcmz on 5/9/21.
//

import Flow
import Foundation

public struct User: Decodable {
    public let addr: Flow.Address
    public private(set) var loggedIn: Bool = false

    var fType: String = "USER"
    var fVsn: String = "1.0.0"
    var services: [Service]? = []
    //        let cid: String
    //        let expiresAt: Date
}
