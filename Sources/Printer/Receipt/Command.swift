//
//  Command.swift
//  Printer
//
//  Created by gix on 2023/2/2.
//

import Foundation

protocol PrintableCommand {
    var value: [UInt8] { get }
}

/// Raw ESC/POS commands. Reference: https://reference.epson-biz.com/modules/ref_escpos/index.php
public enum Command {
    public enum PrintMode: UInt8 {
        case reset = 0
        case selectFontB = 1 // default font A
        case emphasis = 8
        case doubleHeight = 16
        case doubleWidth = 32
        case italic = 64
        case underline = 128
    }

    public enum UnderlineMode: UInt8 {
        case enable = 0
        case enable1dot = 1
        case enable2dot = 2
    }

    public enum CharacterFont: UInt8 {
        case a = 0
        case b = 1
        case c = 2
        case d = 3
    }

    /// Code pages for `ESC t n`. Values follow the Epson ESC/POS table, which most
    /// clones (Gprinter, Xprinter, Munbyn, Rongta, …) use as well.
    ///
    /// The receipt's `PrinterProfile.encoding` must match the page you select, e.g.
    /// `.windowsCP1252` with `.wpc1252`, or `String.Encoding.windowsArabic` with `.wpc1256`.
    public enum CharacterCodePage: UInt8 {
        case pc437 = 0 // USA, standard Europe
        case katakana = 1
        case pc850 = 2 // Multilingual
        case pc860 = 3 // Portuguese
        case pc863 = 4 // Canadian-French
        case pc865 = 5 // Nordic
        case pc851 = 11 // Greek
        case pc853 = 12 // Turkish
        case pc857 = 13 // Turkish
        case pc737 = 14 // Greek
        case iso8859_7 = 15 // Greek
        case wpc1252 = 16 // Western Europe (ä ö ü € …)
        case pc866 = 17 // Cyrillic #2
        case pc852 = 18 // Latin 2
        case pc858 = 19 // Euro
        case thai42 = 20
        case thai11 = 21
        case thai13 = 22
        case thai14 = 23
        case thai16 = 24
        case thai17 = 25
        case thai18 = 26
        case tcvn3_1 = 30 // Vietnamese
        case tcvn3_2 = 31 // Vietnamese
        case pc720 = 32 // Arabic
        case wpc775 = 33 // Baltic Rim
        case pc855 = 34 // Cyrillic
        case pc861 = 35 // Icelandic
        case pc862 = 36 // Hebrew
        case pc864 = 37 // Arabic
        case pc869 = 38 // Greek
        case iso8859_2 = 39 // Latin 2
        case iso8859_15 = 40 // Latin 9
        case pc1098 = 41 // Farsi
        case pc1118 = 42 // Lithuanian
        case pc1119 = 43 // Lithuanian
        case pc1125 = 44 // Ukrainian
        case wpc1250 = 45 // Latin 2
        case wpc1251 = 46 // Cyrillic
        case wpc1253 = 47 // Greek
        case wpc1254 = 48 // Turkish
        case wpc1255 = 49 // Hebrew
        case wpc1256 = 50 // Arabic
        case wpc1257 = 51 // Baltic Rim
        case wpc1258 = 52 // Vietnamese
        case kz1048 = 53 // Kazakh
        case userDefined = 255

        @available(*, deprecated, renamed: "pc437")
        public static var ascii: CharacterCodePage { .pc437 }
        @available(*, deprecated, renamed: "pc437")
        public static var cp437: CharacterCodePage { .pc437 }
        @available(*, deprecated, renamed: "pc866")
        public static var cp808: CharacterCodePage { .pc866 }
    }

    /// International character set for `ESC R n`.
    public enum InternationalCharacterSet: UInt8 {
        case usa = 0, france, germany, uk, denmark1, sweden, italy, spain1, japan, norway
        case denmark2, spain2, latinAmerica, korea, sloveniaCroatia, china, vietnam, arabia
    }

    public enum FontControlling: PrintableCommand {
        case clear
        case initialize
        case selectPrintMode(PrintMode)
        case underlineMode(UnderlineMode)
        case italicsMode(enable: Bool)
        case emphasis(enable: Bool)
        case selectsCharacterFont(CharacterFont)
        case rotation90(enable: Bool)
        case selectCharacterCodePage(CharacterCodePage)
        case selectInternationalCharacterSet(InternationalCharacterSet)
        /// `GS ! n` – width and height magnification, each 1…8.
        case characterSize(width: UInt8, height: UInt8)
        case upsideDownMode(enable: Bool)
        // https://escpos.readthedocs.io/en/latest/font_cmds.html#set-cpi-mode-1b-c1-rel
        case setCPIMode(UInt8)
        case reverseMode(enable: Bool)
        // https://escpos.readthedocs.io/en/latest/font_cmds.html#select-double-strike-mode-1b-47-phx
        case doubleStrikeMode(UInt8)

        var value: [UInt8] {
            switch self {
            case .clear, .initialize:
                return [27, 64]
            case let .selectPrintMode(m):
                return [27, 33, m.rawValue]
            case let .underlineMode(m):
                return [27, 45, m.rawValue]
            case let .italicsMode(enable):
                return [27, 52, enable ? 1 : 0]
            case let .emphasis(enable):
                return [27, 69, enable ? 1 : 0]
            case let .selectsCharacterFont(font):
                switch font {
                case .a, .b:
                    return [27, 77, font.rawValue]
                case .c:
                    return [27, 84]
                case .d:
                    return [27, 85]
                }
            case let .rotation90(enable):
                return [27, 86, enable ? 1 : 0]
            case let .selectCharacterCodePage(c):
                return [27, 116, c.rawValue]
            case let .selectInternationalCharacterSet(set):
                return [27, 82, set.rawValue]
            case let .characterSize(width, height):
                let w = min(max(width, 1), 8) - 1
                let h = min(max(height, 1), 8) - 1
                return [29, 33, (w << 4) | h]
            case let .upsideDownMode(enable):
                return [27, 123, enable ? 1 : 0]
            case let .setCPIMode(n):
                return [27, 193, n]
            case let .reverseMode(enable):
                return [29, 66, enable ? 1 : 0]
            case let .doubleStrikeMode(n):
                return [27, 71, n]
            }
        }
    }

    public enum PrinterID: UInt8 {
        case modelID = 1
        case typeID = 2
        case firmwareRevision = 3
    }

    public enum PrinterInformation: PrintableCommand {
        case printer(_ id: PrinterID)
        /// `GS r 1` – paper sensor status.
        case transmitStatus
        case transmitPaperSensorStatus
        /// `DLE EOT n` – real-time status (1 printer, 2 offline cause, 3 error cause, 4 paper).
        case realTimeStatus(UInt8)

        var value: [UInt8] {
            switch self {
            case let .printer(id):
                return [29, 73, id.rawValue]
            case .transmitStatus:
                return [29, 114, 1]
            case .transmitPaperSensorStatus:
                return [27, 118]
            case let .realTimeStatus(n):
                return [16, 4, min(max(n, 1), 4)]
            }
        }
    }

    public enum CursorPosition: PrintableCommand {
        case horizontalTab
        case lineFeed
        case formFeed
        case carriageReturn
        case cancelCurrentLine
        // https://escpos.readthedocs.io/en/latest/cursor_position.html#absolute-print-position-1b-24-rel
        case absolutePrintPosition(nL: UInt8, nH: UInt8)
        // https://escpos.readthedocs.io/en/latest/cursor_position.html#relative-print-position-1b-5c-rel
        case relativePrintPosition(nL: UInt8, nH: UInt8)

        var value: [UInt8] {
            switch self {
            case .horizontalTab:
                return [9]
            case .lineFeed:
                return [10]
            case .formFeed:
                return [12]
            case .carriageReturn:
                return [13]
            case .cancelCurrentLine:
                return [24]
            case let .absolutePrintPosition(nL, nH):
                return [27, 36, nL, nH]
            case let .relativePrintPosition(nL, nH):
                return [27, 92, nL, nH]
            }
        }
    }

    public enum PageMovement: PrintableCommand {
        /// `GS V 1` – partial cut (one point left uncut).
        case partialCut
        /// `GS V 0` – full cut.
        case fullCut
        /// `GS V 65/66 n` – feed `lines` dots, then cut.
        case feedAndCut(partial: Bool, feed: UInt8)
        /// Legacy `ESC i` / `ESC m` cuts for old printers that do not support `GS V`.
        case legacyCut(partial: Bool)
        case ejector
        /// `ESC J 0` – flush the line buffer.
        case print
        /// `ESC d n` – print and feed `lines` lines.
        case printAndFeed(lines: UInt8)
        /// `ESC J n` – print and feed `dots` dots (vertical motion units).
        case printAndFeedPaper(dots: UInt8)

        var value: [UInt8] {
            switch self {
            case .partialCut:
                return [29, 86, 1]
            case .fullCut:
                return [29, 86, 0]
            case let .feedAndCut(partial, feed):
                return [29, 86, partial ? 66 : 65, feed]
            case let .legacyCut(partial):
                return partial ? [27, 109] : [27, 105]
            case .ejector:
                return []
            case .print:
                // 0 will be ignored
                return [27, 74, 0]
            case let .printAndFeed(lines):
                return [27, 100, lines]
            case let .printAndFeedPaper(dots):
                return [27, 74, dots]
            }
        }
    }

    public enum LineSpace {
        case l1_6
        case l1_8
        case raw(UInt8)
    }

    public enum Alignment: UInt8 {
        case left = 0
        case center = 1
        case right = 2
    }

    public enum Layout: PrintableCommand {
        case rightSpacing(UInt8)
        case lineSpace(LineSpace)
        case justification(Alignment)
        /// `GS L` – left margin in horizontal motion units.
        case leftMargin(UInt16)
        /// `GS W` – print area width in horizontal motion units.
        case printAreaWidth(UInt16)

        var value: [UInt8] {
            switch self {
            case let .rightSpacing(n):
                return [27, 32, n]
            case let .lineSpace(l):
                switch l {
                case .l1_6:
                    return [27, 50]
                case .l1_8:
                    return [27, 48]
                case let .raw(n):
                    return [27, 51, n]
                }
            case let .justification(a):
                return [27, 97, a.rawValue]
            case let .leftMargin(n):
                return [29, 76, UInt8(n % 256), UInt8(n / 256)]
            case let .printAreaWidth(n):
                return [29, 87, UInt8(n % 256), UInt8(n / 256)]
            }
        }
    }

    public enum Peripheral: PrintableCommand {
        /// `ESC p m t1 t2` – pulse the cash drawer kick-out connector.
        /// `pin` 0 or 1, times in units of 2 ms (default 100 ms on / 500 ms off).
        case cashDrawer(pin: UInt8 = 0, onTime: UInt8 = 50, offTime: UInt8 = 250)

        var value: [UInt8] {
            switch self {
            case let .cashDrawer(pin, onTime, offTime):
                return [27, 112, min(pin, 1), onTime, offTime]
            }
        }
    }

    case style(FontControlling)
    case info(PrinterInformation)
    case cursor(CursorPosition)
    case page(PageMovement)
    case layout(Layout)
    case peripheral(Peripheral)
    /// Escape hatch for vendor-specific commands.
    case raw([UInt8])

    var value: [UInt8] {
        switch self {
        case let .style(fc):
            return fc.value
        case let .info(i):
            return i.value
        case let .cursor(c):
            return c.value
        case let .page(p):
            return p.value
        case let .layout(l):
            return l.value
        case let .peripheral(p):
            return p.value
        case let .raw(bytes):
            return bytes
        }
    }
}
