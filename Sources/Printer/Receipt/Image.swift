//
//  Image.swift
//  Printer
//
//  Created by gix on 2023/2/2.
//

import CoreGraphics
import Foundation
#if canImport(ImageIO)
    import ImageIO
#endif

/// Prints a bitmap with the `GS v 0` raster command.
///
/// The image is re-rendered into an 8-bit grayscale buffer first, so any
/// `CGImage` (RGB, RGBA, gray, indexed, with or without alpha, padded rows…)
/// is accepted and can no longer crash with "Index out of range".
///
/// Images wider than the printer's dot width are scaled down proportionally
/// unless `scaling` is `.none`. Transparent pixels are treated as white.
///
/// Long images are split into bands of `rowsPerBand` rows, each sent as its
/// own raster command. This keeps every command small enough for printers with
/// tiny receive buffers and lets Bluetooth printers start printing before the
/// whole picture has arrived.
public struct ImageItem: ReceiptItem {
    public enum Mode: UInt8 {
        case normal = 0
        case doubleWidth = 1
        case doubleHeight = 2
        case doubleWH = 3
    }

    /// How gray pixels are turned into black and white dots.
    public enum Binarization {
        /// Pixels darker than `threshold` (0…255) are printed black.
        case threshold(UInt8)
        /// Floyd–Steinberg error diffusion. Best for photos and anti-aliased text.
        case dither
    }

    public enum Scaling {
        /// Send the image at its native pixel size (pixels beyond the paper are dropped by the printer).
        case none
        /// Scale down proportionally so that the image fits `PrinterProfile.maxWidthDensity`.
        case fitWidth
    }

    public let cgImage: CGImage
    public let mode: Mode
    public var binarization: Binarization
    public var scaling: Scaling
    /// Rows per `GS v 0` command. `0` sends the whole image in one command.
    public var rowsPerBand: Int

    public var width: Int { cgImage.width }
    public var height: Int { cgImage.height }

    public init(_ cgImage: CGImage,
                grayThreshold: UInt8 = 128,
                mode: Mode = .normal,
                scaling: Scaling = .fitWidth,
                rowsPerBand: Int = 64)
    {
        self.init(cgImage, binarization: .threshold(grayThreshold), mode: mode, scaling: scaling, rowsPerBand: rowsPerBand)
    }

    public init(_ cgImage: CGImage,
                binarization: Binarization,
                mode: Mode = .normal,
                scaling: Scaling = .fitWidth,
                rowsPerBand: Int = 64)
    {
        self.cgImage = cgImage
        self.binarization = binarization
        self.mode = mode
        self.scaling = scaling
        self.rowsPerBand = max(0, rowsPerBand)
    }

    #if canImport(ImageIO)
        /// Decodes PNG / JPEG / … data (e.g. a downloaded or base64-decoded picture).
        public init?(data: Data,
                     binarization: Binarization = .threshold(128),
                     mode: Mode = .normal,
                     scaling: Scaling = .fitWidth,
                     rowsPerBand: Int = 64)
        {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
            else {
                return nil
            }
            self.init(image, binarization: binarization, mode: mode, scaling: scaling, rowsPerBand: rowsPerBand)
        }

        /// Decodes a base64 string, with or without a `data:image/...;base64,` prefix.
        public init?(base64: String,
                     binarization: Binarization = .threshold(128),
                     mode: Mode = .normal,
                     scaling: Scaling = .fitWidth,
                     rowsPerBand: Int = 64)
        {
            var payload = Substring(base64)
            if let comma = payload.firstIndex(of: ","), payload.lowercased().hasPrefix("data:") {
                payload = payload[payload.index(after: comma)...]
            }
            guard let data = Data(base64Encoded: String(payload), options: .ignoreUnknownCharacters) else {
                return nil
            }
            self.init(data: data, binarization: binarization, mode: mode, scaling: scaling, rowsPerBand: rowsPerBand)
        }
    #endif

    // MARK: - ReceiptItem

    public func assemblePrintableData(_ profile: PrinterProfile) -> [UInt8] {
        guard let bitmap = Bitmap(cgImage, targetWidth: targetWidth(for: profile), binarization: binarization) else {
            return []
        }
        return rasterCommands(bitmap)
    }

    /// The pixel width the image is rendered at before being sent.
    func targetWidth(for profile: PrinterProfile) -> Int {
        guard scaling == .fitWidth, profile.maxWidthDensity > 0 else {
            return cgImage.width
        }
        let doubles = mode == .doubleWidth || mode == .doubleWH
        let maxWidth = doubles ? profile.maxWidthDensity / 2 : profile.maxWidthDensity
        return min(cgImage.width, max(8, maxWidth))
    }

    private func rasterCommands(_ bitmap: Bitmap) -> [UInt8] {
        let widthBytes = bitmap.widthBytes
        let band = rowsPerBand == 0 ? bitmap.height : rowsPerBand
        var data = [UInt8]()
        data.reserveCapacity(bitmap.rows.count + (bitmap.height / max(band, 1) + 1) * 8)

        var y = 0
        while y < bitmap.height {
            let rows = min(band, bitmap.height - y)
            data += [29, 118, 48, mode.rawValue]
            data += [UInt8(widthBytes % 256), UInt8(widthBytes / 256), UInt8(rows % 256), UInt8(rows / 256)]
            data += bitmap.rows[(y * widthBytes) ..< ((y + rows) * widthBytes)]
            y += rows
        }
        return data
    }
}

/// 1-bit-per-pixel, MSB first, `1` = black. Rows are padded to whole bytes.
struct Bitmap {
    let width: Int
    let height: Int
    let widthBytes: Int
    let rows: [UInt8]

    init?(_ image: CGImage, targetWidth: Int, binarization: ImageItem.Binarization) {
        guard image.width > 0, image.height > 0, targetWidth > 0 else {
            return nil
        }
        let width = targetWidth
        let height = max(1, Int((Double(image.height) * Double(width) / Double(image.width)).rounded()))

        guard var gray = Bitmap.grayscale(image, width: width, height: height) else {
            return nil
        }

        let widthBytes = (width + 7) / 8
        var rows = [UInt8](repeating: 0, count: widthBytes * height)

        switch binarization {
        case let .threshold(threshold):
            for y in 0 ..< height {
                for x in 0 ..< width where gray[y * width + x] < Int(threshold) {
                    rows[y * widthBytes + x / 8] |= 0x80 >> UInt8(x % 8)
                }
            }
        case .dither:
            for y in 0 ..< height {
                for x in 0 ..< width {
                    let index = y * width + x
                    let old = gray[index]
                    let new = old < 128 ? 0 : 255
                    if new == 0 {
                        rows[y * widthBytes + x / 8] |= 0x80 >> UInt8(x % 8)
                    }
                    let error = old - new
                    if x + 1 < width { gray[index + 1] += error * 7 / 16 }
                    if y + 1 < height {
                        if x > 0 { gray[index + width - 1] += error * 3 / 16 }
                        gray[index + width] += error * 5 / 16
                        if x + 1 < width { gray[index + width + 1] += error * 1 / 16 }
                    }
                }
            }
        }

        self.width = width
        self.height = height
        self.widthBytes = widthBytes
        self.rows = rows
    }

    /// Renders `image` into an 8-bit gray buffer of `width`×`height`, white background.
    private static func grayscale(_ image: CGImage, width: Int, height: Int) -> [Int]? {
        var buffer = [UInt8](repeating: 255, count: width * height)
        let ok: Bool = buffer.withUnsafeMutableBytes { raw in
            guard let base = raw.baseAddress,
                  let context = CGContext(data: base,
                                          width: width,
                                          height: height,
                                          bitsPerComponent: 8,
                                          bytesPerRow: width,
                                          space: CGColorSpaceCreateDeviceGray(),
                                          bitmapInfo: CGImageAlphaInfo.none.rawValue)
            else {
                return false
            }
            context.interpolationQuality = .high
            context.setFillColor(gray: 1, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return ok ? buffer.map { Int($0) } : nil
    }
}
