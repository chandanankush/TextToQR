//
//  QRCodeGenerator.swift
//  QRCodeGenerator
//
//  Created by Chandan Singh on 09/05/23.
//

import Foundation
import Cocoa
import CoreImage
import CoreGraphics

struct QRCodeGenerator {

    static func getQRImageUsingNew(qrcode: String) -> NSImage? {
        
        guard !qrcode.isEmpty else {
            return nil
        }
       
        let image = generateQRCode(from: qrcode, quality: "H")
       
        guard let image = image else {
            return nil
        }
        // Create an NSImage from the CGImage
        let qrCodeImage = convertCIImageToNSImage(image)
        return qrCodeImage
    }
    
    static func generateQRCode(from string: String, quality: String) -> CIImage? {
        let qrFilter = CIFilter(name: "CIQRCodeGenerator")
        let data = string.data(using: String.Encoding.ascii)
        qrFilter?.setValue(data, forKey: "inputMessage")
        qrFilter?.setValue(quality, forKey: "inputCorrectionLevel")
        
        guard let qrCodeImage = qrFilter?.outputImage else { return nil }
        
        let scaleX = 300 / qrCodeImage.extent.size.width
        let scaleY = 300 / qrCodeImage.extent.size.height
        let transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
        let output = qrCodeImage.transformed(by: transform)
        return output
    }
    
    static func convertCIImageToNSImage(_ ciImage: CIImage) -> NSImage? {
        let rep = NSCIImageRep(ciImage: ciImage)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)
        return nsImage
    }
}

