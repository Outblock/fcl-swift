//
//  File.swift
//
//
//  Created by Hao Fu on 15/2/22.
//

import BigInt
import Flow
import Foundation

extension FCL {
    enum WalletUtil {
        static func encodeMessageForProvableAuthnSigning(address: Flow.Address,
                                                         timestamp: TimeInterval,
                                                         appDomainTag: String? = nil) -> String
        {
            let userDomainTag = Flow.DomainTag.user

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
            return (userDomainTag.normalize + result).hexValue
        }
    }
}
