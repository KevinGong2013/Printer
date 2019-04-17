//
//  Receipt.swift
//  Printer
//
//  Created by gix on 12/10/16.
//  Copyright © 2016 Kevin. All rights reserved.
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

public struct Receipt {

    public var feedPointsPerLine: UInt8 = 70
    public var feedLinesOnTail: UInt8 = 3
    
    fileprivate var blocks = [Block]()

    public init(_ blocks: Block...) {
        self.blocks = blocks
    }

    public mutating func add(block: Block) {
        blocks.append(block)
    }
}

extension Receipt: Printable {

    public func data(using encoding: String.Encoding) -> [Data] {
        var ds = blocks.map { Data.reset + $0.data(using: encoding) + Data.print(feedPointsPerLine) }
        
        let data = Data(esc_pos: .printAndFeed(lines: feedLinesOnTail))
        ds.append(data)
        
        return ds
    }
}
