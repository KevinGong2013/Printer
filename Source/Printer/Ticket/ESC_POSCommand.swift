//
//  ESC_POSCommand.swift
//  Ticket
//
//  Created by gix on 2019/6/30.
//  Copyright © 2019 gix. All rights reserved.
//

import Foundation

extension Data {
    
    init(esc_pos cmd: ESC_POSCommand...) {
        self.init(cmd.reduce([], { (r, cmd) -> [UInt8] in
            return r + cmd.rawValue
        }))
    }
    
    static var reset: Data {
        return Data(esc_pos: .initialize)
    }
    
    static func print(_ feed: UInt8) -> Data {
        return Data(esc_pos: .feed(points: feed))
    }
}

public struct ESC_POSCommand: RawRepresentable {
    
    public typealias RawValue = [UInt8]
    
    public let rawValue: [UInt8]
    
    public init(rawValue: [UInt8]) {
        self.rawValue = rawValue
    }
    
    public init(_ rawValue: [UInt8]) {
        self.rawValue = rawValue
    }
}

// ref: http://content.epson.de/fileadmin/content/files/RSD/downloads/escpos.pdf

//Control Commands
extension ESC_POSCommand {
    
    // Clears the data in the print buffer and resets the printer modes to the modes that were in effect when the power was turned on.
    static let initialize = ESC_POSCommand(rawValue: [27, 64])
    
    // Prints the data in the print buffer and feeds n lines.
    static func printAndFeed(lines: UInt8 = 1) -> ESC_POSCommand {
        return ESC_POSCommand([27, 100, lines])
    }
    
    static func feed(points: UInt8) -> ESC_POSCommand {
        return ESC_POSCommand([27, 74, points])
    }
    
    // Prints the data in the print buffer and feeds n lines in the reverse direction.
    static func printAndReverseFeed(lines: UInt8 = 1) -> ESC_POSCommand {
        return ESC_POSCommand([27, 101, lines])
    }
    
    // Turn emphasized mode on/off
    static func emphasize(mode: Bool) -> ESC_POSCommand {
        return ESC_POSCommand([27, 69, mode ? 1 : 0])
    }
    
    // Select character font
    static func font(_ n: UInt8) -> ESC_POSCommand {
        return ESC_POSCommand([27, 77, n])
    }
    
    // Selects the printing color specified by n
    static func color(n: UInt8) -> ESC_POSCommand {
        return ESC_POSCommand([27, 114, n])
    }
    
    // Turn white/black reverse printing mode on/off
    static func whiteBlackReverse(mode: Bool) -> ESC_POSCommand {
        return ESC_POSCommand([29, 66, mode ? 1 : 0])
    }
    
    // Aligns all the data in one line to the position specified by n as follows:
    static func justification(_ n: UInt8) -> ESC_POSCommand {
        return ESC_POSCommand([27, 97, n])
    }
    
    // Selects the character font and styles (emphasize, double-height, double-width, and underline) together.
    static func print(modes n: UInt8) -> ESC_POSCommand {
        return ESC_POSCommand([27, 33, n])
    }
    
    // Turns underline mode on or off
    static func underline(mode: UInt8) -> ESC_POSCommand {
        return ESC_POSCommand([27, 45, mode])
    }
    
    enum ImageSize: UInt8 {
        case normal = 48
        case doubleWidth = 49
        case doubleHeight = 50
        case doubleSize = 51
    }
    
    // modified Pradeep Sakharelia 18/05/2019
    static func beginPrintImage(m: ImageSize = .normal, xl: UInt8, xH: UInt8, yl: UInt8, yH: UInt8) -> ESC_POSCommand {
        return ESC_POSCommand(rawValue: [29, 118, 48, m.rawValue, xl, xH, yl, yH])
    }
    
    // Configure QR
    static func QRSetSize(point: UInt8 = 8) -> ESC_POSCommand {
        return ESC_POSCommand([29, 40, 107, 3, 0, 49, 67, point])
    }
    
    static func QRSetRecoveryLevel() -> ESC_POSCommand {
        return  ESC_POSCommand(rawValue: [29, 40, 107, 3, 0, 49, 69, 51])
    }
    
    static func QRGetReadyToStore(text: String) -> ESC_POSCommand {
        
        let s  = text.count + 3
        let pl = s % 256
        let ph = s / 256
        
        return ESC_POSCommand([29, 40, 107, UInt8(pl), UInt8(ph), 49, 80, 48])
    }
    
    static func QRPrint() -> ESC_POSCommand {
        return ESC_POSCommand([29, 40, 107, 3, 0, 49, 81, 48])
    }
}
