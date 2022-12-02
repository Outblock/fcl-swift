//
//  FCLDemoApp.swift
//  FCLDemo
//
//  Created by lmcmz on 30/8/21.
//

import SwiftUI
#if DEBUG
import Atlantis
#endif

@main
struct FCLDemoApp: App {
    
    init () {
        #if DEBUG
            Atlantis.start()
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
