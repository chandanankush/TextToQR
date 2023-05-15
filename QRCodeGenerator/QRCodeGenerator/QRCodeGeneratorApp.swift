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
            ContentView().frame(minWidth: 400, maxWidth: 400, minHeight: 600, maxHeight: 600) // set a fixed window size
            }.windowStyle(HiddenTitleBarWindowStyle()) // optional: hide the window title bar
    }
}
