import AppKit
import Combine
import Foundation
import Printer

enum EncodingChoice: String, CaseIterable, Identifiable {
    case ascii = "ASCII"
    case utf8 = "UTF-8"
    case cp1252 = "Windows-1252 (Western, €)"
    case latin1 = "ISO Latin 1"
    case gb18030 = "GB18030 (Chinese)"
    case arabic = "Windows-1256 (Arabic)"
    case cp1251 = "Windows-1251 (Cyrillic)"
    case cp1253 = "Windows-1253 (Greek)"
    case shiftJIS = "Shift JIS (Japanese)"

    var id: String { rawValue }

    var encoding: String.Encoding {
        switch self {
        case .ascii: return .ascii
        case .utf8: return .utf8
        case .cp1252: return .windowsCP1252
        case .latin1: return .isoLatin1
        case .gb18030: return String.GBEncoding.GB_18030_2000
        case .arabic: return String.ArabicEncoding.windowsArabic
        case .cp1251: return .windowsCP1251
        case .cp1253: return .windowsCP1253
        case .shiftJIS: return .shiftJIS
        }
    }
}

enum CutChoice: String, CaseIterable, Identifiable {
    case none = "None", full = "Full (GS V 0)", partial = "Partial (GS V 1)"
    case feedAndCut = "Feed & partial (GS V 66)", legacyFull = "Legacy ESC i", legacyPartial = "Legacy ESC m"
    var id: String { rawValue }
}

/// Everything the form edits. `receipt` re-renders on every change.
final class ReceiptDraft: ObservableObject {
    // Profile
    @Published var paper80 = false
    @Published var encoding: EncodingChoice = .utf8
    @Published var customWidth = 0 // 0 = use paper default

    // Header
    @Published var initialize = true
    @Published var codePage: Command.CharacterCodePage? = nil
    @Published var internationalSet: Command.InternationalCharacterSet? = nil

    // Text
    @Published var includeText = true
    @Published var text = "PrinterLab\nÄäÖöÜü € 中文 العربية\n0123456789"
    @Published var bold = false
    @Published var underline: Command.UnderlineMode? = nil
    @Published var charWidth = 1.0
    @Published var charHeight = 1.0
    @Published var alignment: Command.Alignment = .left
    @Published var font: Command.CharacterFont = .a
    @Published var reverse = false
    @Published var upsideDown = false
    @Published var rotate90 = false
    @Published var italics = false
    @Published var lineSpacing = 0.0 // 0 = default

    // Key/value + dividing
    @Published var includeKV = true
    @Published var kvText = "Coffee=3.50\nBagel=2.00\nTotal=5.50"
    @Published var dividingChar = "-"

    // Image
    @Published var includeImage = false
    @Published var image: CGImage? = nil
    @Published var imageName = ""
    @Published var threshold = 128.0
    @Published var dither = false
    @Published var imageMode: ImageItem.Mode = .normal
    @Published var fitWidth = true
    @Published var rowsPerBand = 64.0
    @Published var imageAlignment: Command.Alignment = .center

    // QR
    @Published var includeQR = true
    @Published var qrContent = "https://github.com/KevinGong2013/Printer"
    @Published var qrModuleSize = 6.0
    @Published var qrLevel: QRCode.RecoveryLevel = .m
    @Published var qrModel: QRCode.Model = .m_2
    @Published var qrUTF8 = true

    // Barcode
    @Published var includeBarcode = true
    @Published var barcodeContent = "PRINTER-001"
    @Published var symbology: Barcode.Symbology = .code128
    @Published var barcodeHeight = 80.0
    @Published var barcodeWidth = 2.0
    @Published var barcodeText: Barcode.TextPosition = .below

    // Raw
    @Published var includeRaw = false
    @Published var rawHex = "1B 40"

    // Page
    @Published var feedLines = 3.0
    @Published var cut: CutChoice = .none
    @Published var cashDrawer = false
    @Published var drawerPin = 0

    var profile: PrinterProfile {
        let width = customWidth > 0 ? customWidth : (paper80 ? 576 : 384)
        return PrinterProfile(maxWidthDensity: width, fontDensity: font == .b ? 9 : 12, encoding: encoding.encoding)
    }

    var receipt: Receipt {
        let r = Receipt(profile)

        if initialize { r.append(item: Command.style(.initialize)) }
        if let page = codePage { r.append(item: Command.style(.selectCharacterCodePage(page))) }
        if let set = internationalSet { r.append(item: Command.style(.selectInternationalCharacterSet(set))) }

        if includeText {
            r.append(item: Command.layout(.justification(alignment)))
            r.append(item: Command.style(.selectsCharacterFont(font)))
            if bold { r.append(item: Command.style(.emphasis(enable: true))) }
            if let u = underline { r.append(item: Command.style(.underlineMode(u))) }
            if italics { r.append(item: Command.style(.italicsMode(enable: true))) }
            if reverse { r.append(item: Command.style(.reverseMode(enable: true))) }
            if upsideDown { r.append(item: Command.style(.upsideDownMode(enable: true))) }
            if rotate90 { r.append(item: Command.style(.rotation90(enable: true))) }
            if lineSpacing > 0 { r.append(item: Command.layout(.lineSpace(.raw(UInt8(lineSpacing))))) }
            r.append(item: Command.style(.characterSize(width: UInt8(charWidth), height: UInt8(charHeight))))
            for line in text.components(separatedBy: "\n") {
                r.append(item: line)
            }
            // undo the styles so the following items print normally
            r.append(item: Command.style(.characterSize(width: 1, height: 1)))
            if bold { r.append(item: Command.style(.emphasis(enable: false))) }
            if underline != nil { r.append(item: Command.style(.underlineMode(.enable))) }
            if italics { r.append(item: Command.style(.italicsMode(enable: false))) }
            if reverse { r.append(item: Command.style(.reverseMode(enable: false))) }
            if upsideDown { r.append(item: Command.style(.upsideDownMode(enable: false))) }
            if rotate90 { r.append(item: Command.style(.rotation90(enable: false))) }
            if lineSpacing > 0 { r.append(item: Command.layout(.lineSpace(.l1_6))) }
            r.append(item: Command.layout(.justification(.left)))
        }

        if includeKV {
            let divider = dividingChar.first ?? "-"
            r.append(item: Dividing.default(provider: divider))
            for line in kvText.components(separatedBy: "\n") where !line.isEmpty {
                let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
                r.append(item: KVItem(parts.first ?? "", parts.count > 1 ? parts[1] : ""))
            }
            r.append(item: Dividing.default(provider: divider))
        }

        if includeImage, let image = image {
            r.append(item: Command.layout(.justification(imageAlignment)))
            r.append(item: ImageItem(image,
                                     binarization: dither ? .dither : .threshold(UInt8(threshold)),
                                     mode: imageMode,
                                     scaling: fitWidth ? .fitWidth : .none,
                                     rowsPerBand: Int(rowsPerBand)))
            r.append(item: Command.layout(.justification(.left)))
        }

        if includeQR {
            r.append(item: Command.layout(.justification(.center)))
            r.append(item: QRCode(content: qrContent,
                                  moduleSize: UInt8(qrModuleSize),
                                  recovery: qrLevel,
                                  model: qrModel,
                                  encoding: qrUTF8 ? .utf8 : nil))
            r.append(item: Command.layout(.justification(.left)))
        }

        if includeBarcode {
            r.append(item: Command.layout(.justification(.center)))
            r.append(item: Barcode(barcodeContent,
                                   symbology: symbology,
                                   height: UInt8(barcodeHeight),
                                   moduleWidth: UInt8(barcodeWidth),
                                   text: barcodeText))
            r.append(item: Command.layout(.justification(.left)))
        }

        if includeRaw {
            r.append(item: Command.raw(Self.parseHex(rawHex)))
        }

        if feedLines > 0 { r.append(item: Command.page(.printAndFeed(lines: UInt8(feedLines)))) }
        if cashDrawer { r.append(item: Command.peripheral(.cashDrawer(pin: UInt8(drawerPin)))) }
        switch cut {
        case .none: break
        case .full: r.append(item: Command.page(.fullCut))
        case .partial: r.append(item: Command.page(.partialCut))
        case .feedAndCut: r.append(item: Command.page(.feedAndCut(partial: true, feed: 0)))
        case .legacyFull: r.append(item: Command.page(.legacyCut(partial: false)))
        case .legacyPartial: r.append(item: Command.page(.legacyCut(partial: true)))
        }
        return r
    }

    var bytes: Data { receipt.bytes }

    func loadImage(from url: URL) {
        guard let nsImage = NSImage(contentsOf: url),
              let cg = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return }
        image = cg
        imageName = "\(url.lastPathComponent) (\(cg.width)×\(cg.height))"
        includeImage = true
    }

    static func parseHex(_ text: String) -> [UInt8] {
        let cleaned = text.replacingOccurrences(of: "0x", with: "")
            .components(separatedBy: CharacterSet(charactersIn: " ,\n\t")).joined()
        var bytes = [UInt8]()
        var index = cleaned.startIndex
        while index < cleaned.endIndex {
            let next = cleaned.index(index, offsetBy: 2, limitedBy: cleaned.endIndex) ?? cleaned.endIndex
            if let value = UInt8(cleaned[index ..< next], radix: 16) { bytes.append(value) }
            index = next
        }
        return bytes
    }
}

extension Data {
    /// `0000  1B 40 48 65 ...  |.@He...|`
    func hexDump(maxBytes: Int = 4096) -> String {
        var lines = [String]()
        let slice = prefix(maxBytes)
        var offset = 0
        while offset < slice.count {
            let row = slice[slice.startIndex + offset ..< slice.startIndex + Swift.min(offset + 16, slice.count)]
            let hex = row.map { String(format: "%02X", $0) }.joined(separator: " ")
            let ascii = row.map { $0 >= 32 && $0 < 127 ? String(UnicodeScalar($0)) : "." }.joined()
            lines.append(String(format: "%06X  %-47@  |%@|", offset, hex as NSString, ascii as NSString))
            offset += 16
        }
        if count > maxBytes { lines.append("… \(count - maxBytes) more bytes") }
        return lines.joined(separator: "\n")
    }
}
