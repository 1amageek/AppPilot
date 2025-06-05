//
//  TestAppApp.swift
//  TestApp
//
//  Created by Norikazu Muramoto on 2025/06/05.
//

import SwiftUI

@main
struct TestAppApp: App {
    var body: some Scene {
        WindowGroup("AppMCP Test App") {
            ContentView()
        }
        .windowResizability(.contentSize)
        .windowToolbarStyle(.unified)
    }
}
