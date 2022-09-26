//
//  File.swift
//  
//
//  Created by Hao Fu on 26/9/2022.
//

import Foundation
import Flow
import Combine
import WalletConnectSign

extension FCL {
    class WalletConnectProvider: FCLStrategy {
        func execService(type: FCL.ServiceType, data: Encodable) async throws -> Any {
            return 1
        }
        
//        
//        func authn() async throws -> FCLResponse {
//            
//        }
//        
//        
//        func mutate() async throws -> Flow.ID {
//            
//        }
//        
//        func signUserMessage() async throws -> FCLUserSignatureResponse {
//            
//        }
    }
}
