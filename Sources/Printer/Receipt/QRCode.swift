//
//  QRCode.swift
//  Printer
//
//  Created by gix on 2023/2/2.
//

import Foundation

/// Prints a QR Code with the printer's built-in symbol generator (`GS ( k`, cn = 49).
///
/// Command sequence per the Epson ESC/POS reference:
/// 1. fn 65 – select model
/// 2. fn 67 – set module size
/// 3. fn 69 – set error correction level
/// 4. fn 80 – store data in the symbol storage area
/// 5. fn 81 – print the stored symbol
public struct QRCode: ReceiptItem {
    public enum Model: UInt8 {
        case m_1 = 49
        case m_2 = 50
        case micro = 51
    }

    public enum RecoveryLevel: UInt8 {
        case l = 48 // 7%
        case m = 49 // 15%
        case q = 50 // 25%
        case h = 51 // 30%
    }

    public let content: String
    public let model: Model
    public let level: RecoveryLevel
    /// Size of one module (dot) in printer dots, 1…16.
    public let moduleSize: UInt8
    /// Encoding used for `content`. `nil` uses the receipt profile's encoding.
    public let encoding: String.Encoding?

    public init(content: String,
                moduleSize: UInt8 = 6,
                recovery level: RecoveryLevel = .m,
                model: Model = .m_2,
                encoding: String.Encoding? = nil)
    {
        self.content = content
        self.moduleSize = min(max(moduleSize, 1), 16)
        self.level = level
        self.model = model
        self.encoding = encoding
    }

    @available(*, deprecated, message: "`width` never was a valid module size; use `moduleSize:` (1…16).")
    public init(content: String, width _: UInt8, recovery level: RecoveryLevel = .m, m: Model = .m_2) {
        self.init(content: content, moduleSize: 6, recovery: level, model: m)
    }

    @available(*, deprecated, renamed: "model")
    public var m: Model { model }

    public func assemblePrintableData(_ profile: PrinterProfile) -> [UInt8] {
        let encoding = encoding ?? profile.encoding
        guard let contentData = content.data(using: encoding, allowLossyConversion: true)
            ?? content.data(using: .utf8),
            !contentData.isEmpty, contentData.count <= 7089
        else {
            return []
        }

        var data = [UInt8]()
        // Select the model
        data += [29, 40, 107, 4, 0, 49, 65, model.rawValue, 0]
        // Set the module size
        data += [29, 40, 107, 3, 0, 49, 67, moduleSize]
        // Select the error correction level
        data += [29, 40, 107, 3, 0, 49, 69, level.rawValue]
        // Store the data in the symbol storage area
        let total = contentData.count + 3
        data += [29, 40, 107, UInt8(total % 256), UInt8(total / 256), 49, 80, 48] + contentData
        // Print the symbol data in the symbol storage area
        data += [29, 40, 107, 3, 0, 49, 81, 48]
        return data
    }
}
