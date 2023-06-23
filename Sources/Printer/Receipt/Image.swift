//
//  ImageItem.swift
//  Printer
//
//  Created by gix on 2023/2/2.
//

import CoreGraphics
import Foundation

public struct ImageItem: ReceiptItem {
    public enum Mode: UInt8 {
        case normal = 0
        case doubleWidth = 1
        case doubleHeight = 2
        case doubleWH = 3
    }

    let mode: Mode
    let cgImage: CGImage
    let width: Int
    let height: Int

    let grayThreshold: UInt8

    public init(_ cgImage: CGImage, grayThreshold: UInt8 = 128, mode: Mode = .normal) {
        self.cgImage = cgImage
        self.mode = mode
        self.width = cgImage.width
        self.height = cgImage.height
        self.grayThreshold = grayThreshold
    }

    public func assemblePrintableData(_ profile: PrinterProfile) -> [UInt8] {
        var data = [29, 118, 48, mode.rawValue]

        // 一个字节8位
        let widthBytes = (width + 7) / 8
        //
        let heightPixels = height

        //
        let xl = widthBytes % 256
        let xh = widthBytes / 256

        let yl = height % 256
        let yh = height / 256

        data.append(contentsOf: [xl, xh, yl, yh].map { UInt8($0) })

        guard let md = cgImage.dataProvider?.data,
              let bytes = CFDataGetBytePtr(md)
        else {
            fatalError("Couldn't access image data")
        }

        let bytesPerPixel = cgImage.bytesPerRow / width

        if cgImage.colorSpace?.model != .rgb && cgImage.colorSpace?.model != .monochrome {
            fatalError("unsupported colourspace mode \(cgImage.colorSpace?.model.rawValue ?? -1)")
        }

        var pixels = [UInt8]()

        for y in 0 ..< height {
            for x in 0 ..< width {
                let offset = (y * cgImage.bytesPerRow) + (x * bytesPerPixel)

                let components = (r: bytes[offset], g: bytes[offset + 1], b: bytes[offset + 2], a: bytes[offset + 3])
                let grayValue = UInt8((Int(components.r) * 38 + Int(components.g) & 75 + Int(components.b) * 15) >> 7)

                pixels.append(grayValue > grayThreshold ? 1 : 0)
//                    0..65535
//                    let grayValue = Int(bytes[offset]) * 256 + Int(bytes[offset + 1])
//                    pixels.append(grayValue > 65535/2 ? 1 : 0)
            }
        }

        var rasterImage = [UInt8]()

        // 现在开始往里面填数据
        for y in 0 ..< heightPixels {
            for w in 0 ..< widthBytes {
                var value = UInt8(0)
                for i in 0 ..< 8 {
                    let x = i + w * 8
                    var ch = UInt8(0)

                    if x < width {
                        let index = y * width + x
                        ch = pixels[index]
                    }

                    value = value << 1
                    value = value | ch
                }
                rasterImage.append(value)
            }
        }

        data.append(contentsOf: rasterImage)

        return data
    }
}
