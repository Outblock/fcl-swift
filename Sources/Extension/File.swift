//
//  File.swift
//  
//
//  Created by Hao Fu on 29/11/2022.
//

import Foundation
import UIKit

extension UIApplication {
    
    var topMostViewController: UIViewController? {
        let vc = UIApplication.shared.connectedScenes.filter {
            $0.activationState == .foregroundActive
        }.first(where: { $0 is UIWindowScene })
            .flatMap( { $0 as? UIWindowScene })?.windows
            .first(where: \.isKeyWindow)?
            .rootViewController?
            .topMostViewController()
        
        return vc
    }

}

extension UIViewController {
    
    func topMostViewController() -> UIViewController? {
        if self.presentedViewController == nil {
            return self
        }
        
        if let navigation = self.presentedViewController as? UINavigationController {
            return navigation.visibleViewController!.topMostViewController()
        }
        
        if let tab = self.presentedViewController as? UITabBarController {
            if let selectedTab = tab.selectedViewController {
                return selectedTab.topMostViewController()
            }
            return tab.topMostViewController()
        }
        
        return self.presentedViewController?.topMostViewController()
    }
    
}
