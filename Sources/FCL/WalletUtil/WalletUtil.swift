//
//  File.swift
//  
//
//  Created by Hao Fu on 15/2/22.
//

import Foundation
import Flow
import BigInt

extension FCL {
    class WalletUtil {
        static func encodeMessageForProvableAuthnSigning(address: Flow.Address,
                                                         timestamp: TimeInterval,
                                                         appDomainTag: String? = nil) -> String {
            let USER_DOMAIN_TAG = Flow.DomainTag.user
            
            var rlpList: [Any] = []
            if let tag = appDomainTag {
                rlpList.append(Flow.DomainTag.custom(tag))
            } else if let tag = fcl.config.get(.domainTag) {
                rlpList.append(Flow.DomainTag.custom(tag))
            }
            
            let addressData = address.data.paddingZeroLeft(blockSize: 8)
            rlpList.append(addressData)
            
            let time = BigUInt(UInt64(timestamp))
            rlpList.append(time)
            
            let result = RLP.encode(rlpList) ?? Data()
            return (USER_DOMAIN_TAG.normalize + result).hexValue
        }
    }
}
