//
//  Block.swift
//  Ticket
//
//  Created by gix on 2019/6/30.
//  Copyright © 2019 gix. All rights reserved.
//

import Foundation

public protocol Printable {
    func data(using encoding: String.Encoding) -> Data
}

public protocol BlockDataProvider: Printable { }

public protocol Attribute {
    var attribute: [UInt8] { get }
}

public struct Block: Printable {

    public static var defaultFeedPoints: UInt8 = 70
    
    private let feedPoints: UInt8
    private let dataProvider: BlockDataProvider
    
    public init(_ dataProvider: BlockDataProvider, feedPoints: UInt8 = Block.defaultFeedPoints) {
        self.feedPoints = feedPoints
        self.dataProvider = dataProvider
    }
    
    public func data(using encoding: String.Encoding) -> Data {
        return dataProvider.data(using: encoding) + Data.print(feedPoints)
    }
}

public extension Block {
    // blank line
    static var blank = Block(Blank())
    
    static func blank(_ line: UInt8) -> Block {
        return Block(Blank(), feedPoints: Block.defaultFeedPoints * line)
    }
    
    // qr
    static func qr(_ content: String) -> Block {
        return Block(QRCode(content))
    }
    
    // title
    static func title(_ content: String) -> Block {
        return Block(Text.title(content))
    }
    
    // plain text
    static func plainText(_ content: String) -> Block {
        return Block(Text.init(content))
    }
    
    static func text(_ text: Text) -> Block {
        return Block(text)
    }
    
    // key    value
    static func kv(k: String, v: String) -> Block {
        return Block(Text.kv(k: k, v: v))
    }
    
    // dividing
    static var dividing = Block(Dividing.default)
    
    // image
    static func image(_ im: Image, attributes: TicketImage.PredefinedAttribute...) -> Block {
        return Block(TicketImage(im, attributes: attributes))
    }
    
}
