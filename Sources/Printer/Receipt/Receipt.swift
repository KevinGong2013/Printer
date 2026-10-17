//
//  Receipt.swift
//  Printer
//
//  Created by gix on 2023/2/2.
//

import Foundation

public extension String {
    enum GBEncoding {
        /// Most Chinese-market printers (Gprinter, Xprinter, …) expect GB18030 / GBK bytes.
        public static let GB_18030_2000 = String.Encoding(
            rawValue: CFStringConvertEncodingToNSStringEncoding(
                CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
    }

    enum ArabicEncoding {
        /// Windows-1256. Pair with `Command.CharacterCodePage.wpc1256`.
        public static let windowsArabic = String.Encoding(
            rawValue: CFStringConvertEncodingToNSStringEncoding(
                CFStringEncoding(CFStringEncodings.windowsArabic.rawValue)))
    }
}

/// Describes the paper width and font of the target printer.
public struct PrinterProfile {
    /// Printable width in dots (58 mm paper: 384, 80 mm paper: 576).
    public let maxWidthDensity: Int
    /// Width of one character cell in dots (font A: 12, font B: 9).
    public let fontDensity: Int
    public let encoding: String.Encoding

    public init(maxWidthDensity: Int, fontDensity: Int, encoding: String.Encoding) {
        self.maxWidthDensity = maxWidthDensity
        self.fontDensity = max(1, fontDensity)
        self.encoding = encoding
    }

    /// Characters per line for `KVItem` and `Dividing`.
    public var charactersPerLine: Int {
        maxWidthDensity / fontDensity
    }
}

public extension PrinterProfile {
    /// 58 mm paper, 384 dots, font A.
    static func 🖨️58(_ encoding: String.Encoding = .ascii) -> PrinterProfile {
        PrinterProfile(maxWidthDensity: 384, fontDensity: 12, encoding: encoding)
    }

    /// 80 mm paper, 576 dots, font A.
    static func 🖨️80(_ encoding: String.Encoding = .ascii) -> PrinterProfile {
        PrinterProfile(maxWidthDensity: 576, fontDensity: 12, encoding: encoding)
    }

    static func paper58(_ encoding: String.Encoding = .ascii) -> PrinterProfile { 🖨️58(encoding) }
    static func paper80(_ encoding: String.Encoding = .ascii) -> PrinterProfile { 🖨️80(encoding) }
}

/// An ordered list of `ReceiptItem`s that is rendered to ESC/POS bytes on demand.
public class Receipt {
    public let profile: PrinterProfile

    fileprivate var items = [ReceiptItem]()

    public init(_ profile: PrinterProfile) {
        self.profile = profile
    }

    public func append(item: ReceiptItem) {
        items.append(item)
    }

    public var data: [UInt8] {
        items.map { $0.assemblePrintableData(profile) }.reduce([], +)
    }

    /// Same as `data`, as `Data`.
    public var bytes: Data {
        Data(data)
    }
}

public protocol ReceiptItem {
    func assemblePrintableData(_ profile: PrinterProfile) -> [UInt8]
}

struct CombineReceiptItem: ReceiptItem {
    let left: ReceiptItem
    let right: ReceiptItem

    func assemblePrintableData(_ profile: PrinterProfile) -> [UInt8] {
        left.assemblePrintableData(profile) + right.assemblePrintableData(profile)
    }
}

precedencegroup ReceiptPrecedence {
    associativity: left
}

infix operator <<<: ReceiptPrecedence

@discardableResult
public func <<< (left: Receipt, right: ReceiptItem) -> Receipt {
    left.items.append(right)
    return left
}

@discardableResult
public func <<< (left: ReceiptItem, right: ReceiptItem) -> ReceiptItem {
    CombineReceiptItem(left: left, right: right)
}

/// Convenience for Xcode
extension Command: ReceiptItem {
    public func assemblePrintableData(_: PrinterProfile) -> [UInt8] {
        value
    }
}

precedencegroup CommandPrecedence {
    associativity: left
    higherThan: ReceiptPrecedence
}

infix operator <<~: CommandPrecedence

@discardableResult
public func <<~ (left: Receipt, right: Command) -> Receipt {
    left <<< right
}

@discardableResult
public func <<~ (left: ReceiptItem, right: Command) -> ReceiptItem {
    left <<< right
}
