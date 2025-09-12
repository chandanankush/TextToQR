//
//  QRCodeGeneratorApp.swift
//  QRCodeGenerator
//
//  Created by Chandan Singh on 09/05/23.
//

import SwiftUI

@main
struct QRCodeGeneratorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600) // wider layout for sidebar + editor
            }.windowStyle(HiddenTitleBarWindowStyle()) // optional: hide the window title bar
    }
}
