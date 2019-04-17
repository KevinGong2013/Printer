//
//  ImageBlock.swift
//  Printer
//
//  Created by gix on 2019/4/10.
//  Copyright © 2019 Kevin. All rights reserved.
//

import Foundation

public protocol ESCPOSEImage {
    var noir: CGImage? { get } // gray scale image
}

extension CGImage: ESCPOSEImage {
    public var noir: CGImage? { return self }
}

extension UIImage: ESCPOSEImage {
    
    public var noir: CGImage? {
        let context = CIContext(options: nil)
        guard let currentFilter = CIFilter(name: "CIPhotoEffectNoir") else { return nil }
        currentFilter.setValue(CIImage(image: self), forKey: kCIInputImageKey)
        return currentFilter.outputImage.flatMap { context.createCGImage($0, from: $0.extent) }
    }
}

struct ImageBlock: PrintableBlock {
    
    let image: ESCPOSEImage
    let maxWidth: CGFloat
    
    init(_ image: ESCPOSEImage, maxWidth: CGFloat) {
        self.image = image
        self.maxWidth = maxWidth
    }
    
    func data(using encoding: String.Encoding) -> Data {
        
        guard let cgImage = image.noir else {
            return debug("CGImage is nil. check your esposeeImage.")
        }
        
        guard let pixelData = cgImage.dataProvider?.data else {
            return debug("Can't get pixelData")
        }
        
        guard let bitmapData = CFDataGetBytePtr(pixelData) else {
            return debug("Can't get bitmapData")
        }
        
        let numberOfComponents = cgImage.bitsPerPixel / cgImage.bitsPerComponent
        
        var imageRawData = Array(repeating: Array(repeating: UInt8(0), count: cgImage.width), count: cgImage.height)
        
        let yBitmapDataIndexStride = stride(from: 0, to: cgImage.height * cgImage.bytesPerRow, by: cgImage.bytesPerRow).enumerated()
        let xBitmapDataIndexStride = stride(from: 0, to: cgImage.width * numberOfComponents, by: numberOfComponents).enumerated()
        
        for (y, yIdx) in yBitmapDataIndexStride {
            for (x, xIdx) in xBitmapDataIndexStride {
                let bitmapIndex = xIdx + yIdx
                imageRawData[y][x] = bitmapData[bitmapIndex] > 127 ? 1 : 0
            }
        }
        
        //
        /**
         根据公式计算出 打印指令需要的参数
         指令:十进制码 1D 76 30 m xL xH yL yH d1...dk
         m为模式，如果是58毫秒打印机，m=1即可
         xL 为宽度/256的余数，由于横向点数计算为像素数/8，因此需要 xL = width/(8*256)
         xH 为宽度/256的整数
         yL 为高度/256的余数
         yH 为高度/256的整数
         **/
        
        let xl = (cgImage.width + 7) % (256 * 8)
        let xH = cgImage.width / (8 * 256)
        let yl = cgImage.height % 256
        let yH = cgImage.height / 256
        
        let dk = imageRawData.reduce([], +) //
        
        var data = Data(esc_pos: .beginPrintImage(xl: UInt8(xl), xH: UInt8(xH), yl: UInt8(yl), yH: UInt8(yH), dk: dk))
        data.append(contentsOf: dk)
        
        return data
    }
    
    //
    func debug(_ message: String) -> Data {
        #if DEBUG
        return Block.text(.init(message)).data(using: String.GBEncoding.GB_18030_2000)
        #else
        return Data()
        #endif
    }
}
