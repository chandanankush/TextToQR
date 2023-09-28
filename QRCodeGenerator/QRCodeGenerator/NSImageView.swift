//
//  NSImageView.swift
//  QRCodeGenerator
//
//  Created by Chandan Singh on 09/05/23.
//

import SwiftUI

struct NSImageView: View {
    var image: NSImage?

    var body: some View {
        if let image = image {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Text("QR will show here when you type in textfield")
        }
    }
}

struct NSImageView_Previews: PreviewProvider {
    static var previews: some View {
        NSImageView()
    }
}
