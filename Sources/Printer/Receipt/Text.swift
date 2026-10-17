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
    ///
    /// On GB2312 / GBK / GB18030 profiles the yen/yuan sign `¥` (U+00A5) is sent as the
    /// full-width `￥` (U+FFE5, `A3 A4`): CoreFoundation would otherwise emit the 4-byte
    /// GB18030 sequence `81 30 84 36`, which GBK-only printers such as the Gprinter GP-58
    /// render as an unrelated ideograph.
    func printableBytes(_ profile: PrinterProfile) -> [UInt8] {
        let string = normalized(for: profile.encoding)
        if let data = string.data(using: profile.encoding) {
            return [UInt8](data)
        }
        if let data = string.data(using: profile.encoding, allowLossyConversion: true) {
            return [UInt8](data)
        }
        return [UInt8](string.utf8)
    }

    /// Characters that have a native two-byte form on GB-family printers.
    private static let gbSubstitutions: [Character: Character] = ["\u{00A5}": "\u{FFE5}"]

    /// The string as it is actually sent to a printer using `encoding`.
    func normalized(for encoding: String.Encoding) -> String {
        guard encoding.isGBFamily, contains(where: { String.gbSubstitutions[$0] != nil }) else { return self }
        return String(map { String.gbSubstitutions[$0] ?? $0 })
    }

    /// Number of character cells the string occupies on a fixed-pitch printer
    /// (full-width CJK characters count as two). Encoding-agnostic; prefer
    /// `printableWidth(_:)` with a profile when laying out a line.
    var printableWidth: Int {
        printableWidth(encoding: nil)
    }

    /// Number of character cells the string occupies when printed with `profile`'s encoding.
    ///
    /// On printers driven by a legacy multi-byte code page (GBK / GB18030, Big5, Shift_JIS,
    /// EUC-KR …) every character that encodes to more than one byte is drawn in a
    /// double-width cell, not only the CJK ideographs: `¥` (U+00A5) becomes a 4-byte GB18030
    /// sequence and prints two cells wide on a Gprinter GP-58, which pushed the last digit of
    /// a right-aligned price onto the next line when it was counted as one cell.
    func printableWidth(_ profile: PrinterProfile) -> Int {
        normalized(for: profile.encoding).printableWidth(encoding: profile.encoding)
    }

    private func printableWidth(encoding: String.Encoding?) -> Int {
        let multiByteCodePage = encoding.map { $0.isLegacyMultiByte } ?? false
        return reduce(0) { width, character in
            if character.isASCII { return width + 1 }
            if character.isFullWidth { return width + 2 }
            if multiByteCodePage, let encoding,
               let data = String(character).data(using: encoding, allowLossyConversion: true),
               data.count > 1 {
                return width + 2
            }
            return width + 1
        }
    }
}

extension String.Encoding {
    var cfEncoding: CFStringEncoding {
        CFStringConvertNSStringEncodingToEncoding(rawValue)
    }

    /// IANA charset name in upper case, e.g. `GB18030`, `CP936`, `UTF-8`; empty when unknown.
    var ianaName: String {
        ((CFStringConvertEncodingToIANACharSetName(cfEncoding) as String?) ?? "").uppercased()
    }

    /// GB2312 / GBK / GB18030 and their Windows / Mac aliases.
    var isGBFamily: Bool {
        let name = ianaName
        return name.hasPrefix("GB") || name == "CP936" || name == "MS936" || name == "EUC-CN"
            || name == "X-MAC-SIMP-CHINESE"
    }

    /// `true` for DBCS-style code pages where "more than one byte" means "two cells".
    var isLegacyMultiByte: Bool {
        let name = ianaName
        if name.isEmpty || name.hasPrefix("UTF") || name.hasPrefix("X-UTF") { return false }
        // kCFStringEncodingUnicode and its UTF-8/16/32 variants share the low bits 0x100.
        if cfEncoding & 0xFFF == CFStringEncoding(CFStringBuiltInEncodings.unicode.rawValue) { return false }
        return CFStringGetMaximumSizeForEncoding(1, cfEncoding) > 1
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
        let spaces = max(1, profile.charactersPerLine - k.printableWidth(profile) - v.printableWidth(profile))
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
