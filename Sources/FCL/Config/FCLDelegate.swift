//
//  File.swift
//  File
//
//  Created by lmcmz on 4/10/21.
//

import AuthenticationServices
import Foundation

public protocol FCLDelegate {
    func showLoading()
    func hideLoading()
}

extension FCLDelegate {
    func presentationAnchor() -> UIWindow {
        return ASPresentationAnchor()
    }
}
