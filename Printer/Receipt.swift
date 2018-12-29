//
//  Receipt.swift
//  Printer
//
//  Created by GongXiang on 12/10/16.
//  Copyright © 2016 Kevin. All rights reserved.
//

import Foundation

extension Data {

    static var reset: Data {
        return Data(bytes: ESC_POSCommand.Initialize.rawValue)
    }

    static func print(_ feed: UInt8) -> Data {
        return Data(bytes: ESC_POSCommand.feed(points: feed).rawValue)
    }
}

extension Data: Block {

    public var data: Data { return self }
}

public protocol Block {

    var data: Data { get }
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

    public var datas: [Data] {

        var ds = blocks.map { Data.reset + $0.data + Data.print(feedPointsPerLine) }

        let data = Data(bytes: ESC_POSCommand.printAndFeed(lines: feedLinesOnTail).rawValue)
        ds.append(data)

        return ds
    }
}
