//
//  Barcode.swift
//  Printer
//

import Foundation

/// Prints a 1D barcode with the printer's built-in generator (`GS k`, function B).
public struct Barcode: ReceiptItem {
    public enum Symbology: UInt8, CaseIterable {
        case upcA = 65
        case upcE = 66
        case ean13 = 67
        case ean8 = 68
        case code39 = 69
        case itf = 70
        case codabar = 71
        case code93 = 72
        case code128 = 73
    }

    /// Where the human readable text is printed.
    public enum TextPosition: UInt8, CaseIterable {
        case none = 0
        case above = 1
        case below = 2
        case both = 3
    }

    public let content: String
    public let symbology: Symbology
    /// Bar height in dots, 1…255.
    public let height: UInt8
    /// Module width, 2…6.
    public let moduleWidth: UInt8
    public let textPosition: TextPosition
    public let font: Command.CharacterFont

    public init(_ content: String,
                symbology: Symbology = .code128,
                height: UInt8 = 80,
                moduleWidth: UInt8 = 3,
                text: TextPosition = .below,
                font: Command.CharacterFont = .a)
    {
        self.content = content
        self.symbology = symbology
        self.height = max(height, 1)
        self.moduleWidth = min(max(moduleWidth, 2), 6)
        textPosition = text
        self.font = font
    }

    public func assemblePrintableData(_: PrinterProfile) -> [UInt8] {
        guard var payload = content.data(using: .ascii).map({ [UInt8]($0) }), !payload.isEmpty else {
            return []
        }
        if symbology == .code128, !(payload.first == 123 /* { */ ) {
            // Default to CODE B (printable ASCII) unless the caller already chose a code set.
            payload = [123, 66] + payload
        }
        guard payload.count <= 255 else {
            return []
        }

        var data = [UInt8]()
        data += [29, 104, height] // GS h – height
        data += [29, 119, moduleWidth] // GS w – module width
        data += [29, 72, textPosition.rawValue] // GS H – HRI position
        data += [29, 102, font == .b ? 1 : 0] // GS f – HRI font
        data += [29, 107, symbology.rawValue, UInt8(payload.count)] + payload
        return data
    }
}
