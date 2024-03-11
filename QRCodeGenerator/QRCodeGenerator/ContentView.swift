//
//  ContentView.swift
//  QRCodeGenerator
//
//  Created by Chandan Singh on 09/05/23.
//

import SwiftUI

struct ContentView: View {
    @State private var qrInputtext = ""
    @State private var image: NSImage?
    
    var body: some View {
        VStack {
            
            HStack {
                TextField("Enter QR String", text: $qrInputtext)
                    .textFieldStyle(RoundedBorderTextFieldStyle()).padding()
                    .onChange(of: qrInputtext) { newValue in
                        image = QRCodeGenerator.getQRImageUsingNew(qrcode: qrInputtext)
                    }
                Button("Render") {
                    image = QRCodeGenerator.getQRImageUsingNew(qrcode: qrInputtext)
                }
            }.padding()
            NSImageView(image: image).padding(.bottom)
            Spacer()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
