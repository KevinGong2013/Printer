//
//  Text.swift
//  Printer
//
//  Created by gix on 2023/2/2.
//

import Foundation

extension String {
    /// Encodes the string for the printer. Characters that cannot be represented in
    /// `profile.encoding` are replaced instead of silently dropping the whole line.
    func printableBytes(_ profile: PrinterProfile) -> [UInt8] {
        if let data = data(using: profile.encoding) {
            return [UInt8](data)
        }
        if let data = data(using: profile.encoding, allowLossyConversion: true) {
            return [UInt8](data)
        }
        return [UInt8](utf8)
    }

    /// Number of character cells the string occupies on a fixed-pitch printer
    /// (full-width CJK characters count as two).
    var printableWidth: Int {
        reduce(0) { $0 + ($1.isFullWidth ? 2 : 1) }
    }
}

extension Character {
    var isFullWidth: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        switch scalar.value {
        case 0x1100 ... 0x115F, 0x2E80 ... 0x303E, 0x3041 ... 0x33FF, 0x3400 ... 0x4DBF,
             0x4E00 ... 0x9FFF, 0xA000 ... 0xA4CF, 0xAC00 ... 0xD7A3, 0xF900 ... 0xFAFF,
             0xFE30 ... 0xFE4F, 0xFF00 ... 0xFF60, 0xFFE0 ... 0xFFE6, 0x20000 ... 0x3FFFD:
            return true
        default:
            return false
        }
    }
}

extension String: ReceiptItem {
    public func assemblePrintableData(_ profile: PrinterProfile) -> [UInt8] {
        printableBytes(profile) + Command.CursorPosition.lineFeed.value
    }
}

/// A line of text that is not followed by a line feed, so several items can share one line.
public struct Text: ReceiptItem {
    public let string: String

    public init(_ string: String) {
        self.string = string
    }

    public func assemblePrintableData(_ profile: PrinterProfile) -> [UInt8] {
        string.printableBytes(profile)
    }
}

/// `key` left aligned and `value` right aligned on one line.
public struct KVItem: ReceiptItem {
    public let k: String
    public let v: String

    public init(_ k: String, _ v: String) {
        self.k = k
        self.v = v
    }

    public func assemblePrintableData(_ profile: PrinterProfile) -> [UInt8] {
        let spaces = max(1, profile.charactersPerLine - k.printableWidth - v.printableWidth)
        return (k + String(repeating: " ", count: spaces) + v).assemblePrintableData(profile)
    }
}

public protocol DividingProvider {
    func character(for current: Int, total: Int) -> Character
}

extension Character: DividingProvider {
    public func character(for _: Int, total _: Int) -> Character {
        self
    }
}

/// A full-width line made of a repeated character, e.g. `--------`.
public struct Dividing: ReceiptItem {
    let provider: DividingProvider

    public static func `default`(provider: Character = Character("-")) -> Dividing {
        Dividing(provider: provider)
    }

    public func assemblePrintableData(_ profile: PrinterProfile) -> [UInt8] {
        let num = profile.charactersPerLine
        let content = (0 ..< num).map { String(provider.character(for: $0, total: num)) }.joined()
        return content.assemblePrintableData(profile)
    }
}
