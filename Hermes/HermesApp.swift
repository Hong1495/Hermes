//
//  HermesApp.swift
//  Hermes
//
//  Created by Hermes AI Assistant.
//

import SwiftUI

@main
struct HermesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
