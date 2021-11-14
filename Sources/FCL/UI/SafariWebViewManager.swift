//
//  File.swift
//
//
//  Created by lmcmz on 14/11/21.
//

import Foundation
import SafariServices

class SafariWebViewManager: NSObject, SFSafariViewControllerDelegate {
    static var shared = SafariWebViewManager()
    var safariVC: SFSafariViewController?
    var onClose: (() -> Void)?

    static func openSafariWebView(url: URL, dismiss _: (() -> Void)?) {
        SafariWebViewManager.shared.onClose = dismiss
        DispatchQueue.main.async {
//                 hideLoading {
            let vc = SFSafariViewController(url: url)
            vc.delegate = SafariWebViewManager.shared
            vc.modalPresentationStyle = .formSheet
            SafariWebViewManager.shared.safariVC = vc

            if var topController = UIApplication.shared.windows.filter({ $0.isKeyWindow }).first?.rootViewController {
                while let presentedViewController = topController.presentedViewController {
                    topController = presentedViewController
                }

                topController.present(vc, animated: true, completion: nil)
            }
//                 }
        }
    }

    static func dismiss() {
        if let vc = SafariWebViewManager.shared.safariVC {
            DispatchQueue.main.async {
                vc.dismiss(animated: true, completion: nil)
            }
        }
    }

    func safariViewControllerDidFinish(_: SFSafariViewController) {
        if let block = SafariWebViewManager.shared.onClose {
            block()
        }
        SafariWebViewManager.shared.onClose = nil
    }
}
