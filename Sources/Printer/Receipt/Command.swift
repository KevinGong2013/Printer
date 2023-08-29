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
    
    public enum CharacterCodePage: UInt8 {
        case ascii = 0
        case cp437 = 3
        case cp808 = 17
        case georgian = 18
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
                return [27, 166, c.rawValue]
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
        case transmitStatus
        case transmitPaperSensorStatus
        
        var value: [UInt8] {
            switch self {
            case let .printer(id):
                return [29, 73, id.rawValue]
            case .transmitStatus:
                debugPrint("⚠️ TODO://")
                return [29, 114, 0]
            case .transmitPaperSensorStatus:
                return [27, 118]
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
        case partialCut
        case fullCut
        case ejector
        case print
        case printAndFeed(lines: UInt8)
        
        var value: [UInt8] {
            switch self {
            case .partialCut:
                return [27, 105]
            case .fullCut:
                return [27, 109]
            case .ejector:
                debugPrint("⚠️ TODO://")
                return []
            case .print:
                // 0 will be ignored
                return [27, 74, 0]
            case let .printAndFeed(lines):
                return [27, 100, lines]
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
        
        /**
         Left Margin
         Motion Units
         Print Area Width
         */
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
            }
        }
    }
    
    case style(FontControlling)
    case info(PrinterInformation)
    case cursor(CursorPosition)
    case page(PageMovement)
    case layout(Layout)
    
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
        }
    }
}
