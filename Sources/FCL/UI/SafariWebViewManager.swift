//
//  File.swift
//
//
//  Created by lmcmz on 14/11/21.
//

import Foundation
import SafariServices

class SafariWebViewManager: NSObject {
    static var shared = SafariWebViewManager()
    var safariVC: SFSafariViewController?
    var delegate: HTTPSessionDelegate?
    
    static func openSafariWebView(url: URL) {
        DispatchQueue.main.async {
            let vc = SFSafariViewController(url: url)
            vc.delegate = SafariWebViewManager.shared
            vc.presentationController?.delegate = SafariWebViewManager.shared
            vc.modalPresentationStyle = .formSheet
//            vc.isModalInPresentation = true
            SafariWebViewManager.shared.safariVC = vc

            if var topController = UIApplication.shared.windows.filter({ $0.isKeyWindow }).first?.rootViewController {
                while let presentedViewController = topController.presentedViewController {
                    topController = presentedViewController
                }

                topController.present(vc, animated: true, completion: nil)
            }
        }
    }

    static func dismiss() {
        if let vc = SafariWebViewManager.shared.safariVC {
            DispatchQueue.main.async {
                vc.dismiss(animated: true, completion: nil)
            }
            SafariWebViewManager.shared.stopPolling()
        }
    }

    func stopPolling() {
        delegate?.isPending = false
    }
}

extension SafariWebViewManager: SFSafariViewControllerDelegate, UIAdaptivePresentationControllerDelegate {
    func safariViewControllerDidFinish(_: SFSafariViewController) {
        stopPolling()
    }

    func presentationControllerDidDismiss(_: UIPresentationController) {
        stopPolling()
    }
}
