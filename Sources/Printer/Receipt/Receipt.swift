//
//  Receipt.swift
//  Printer
//
//  Created by gix on 2023/2/2.
//

import Foundation

public extension String {
    enum GBEncoding {
        // 一般支持中文的打印机 需要设置为这个 编码
        public static let GB_18030_2000 = String.Encoding(
            rawValue: CFStringConvertEncodingToNSStringEncoding(
                CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
    }
}

public extension PrinterProfile {
    static func 🖨️58(_ encoding: String.Encoding = .ascii) -> PrinterProfile {
        return PrinterProfile(maxWidthDensity: 384, fontDensity: 12, encoding: encoding)
    }

    // Welcome add your mode profile.
}

public struct PrinterProfile {
    public let maxWidthDensity: Int
    public let fontDensity: Int

    public let encoding: String.Encoding

    public init(maxWidthDensity: Int, fontDensity: Int, encoding: String.Encoding) {
        self.maxWidthDensity = maxWidthDensity
        self.fontDensity = fontDensity
        self.encoding = encoding
    }
}

//    https://reference.epson-biz.com/modules/ref_escpos/index.php

public class Receipt {
    let profile: PrinterProfile

    fileprivate var items = [ReceiptItem]()

    public init(_ profile: PrinterProfile) {
        self.profile = profile
    }

    public func append(item: ReceiptItem) {
        items.append(item)
    }

    public var data: [UInt8] {
        return items.map { $0.assemblePrintableData(profile) }.reduce([], +)
    }
}

public protocol ReceiptItem {
    func assemblePrintableData(_ profile: PrinterProfile) -> [UInt8]
}

struct CombineReceiptItem: ReceiptItem {
    let left: ReceiptItem
    let right: ReceiptItem

    func assemblePrintableData(_ profile: PrinterProfile) -> [UInt8] {
        return left.assemblePrintableData(profile) + right.assemblePrintableData(profile)
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
    return CombineReceiptItem(left: left, right: right)
}

/// Convernice for Xcode
extension Command: ReceiptItem {
    public func assemblePrintableData(_ profile: PrinterProfile) -> [UInt8] {
        return value
    }
}

precedencegroup CommandPrecedence {
    associativity: left
    higherThan: ReceiptPrecedence
}

infix operator <<~: CommandPrecedence

@discardableResult
public func <<~ (left: Receipt, right: Command) -> Receipt {
    return left <<< right
}

@discardableResult
public func <<~ (left: ReceiptItem, right: Command) -> ReceiptItem {
    return left <<< right
}
