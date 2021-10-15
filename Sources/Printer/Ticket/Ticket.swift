//
//  Ticket.swift
//  Ticket
//
//  Created by gix on 2019/6/30.
//  Copyright © 2019 gix. All rights reserved.
//

import Foundation

public struct Ticket {
    
    public var feedLinesOnTail: UInt8 = 3
    public var feedLinesOnHead: UInt8 = 0
    
    private var blocks = [Block]()
    
    public init(_ blocks: Block...) {
        self.blocks = blocks
    }
    
    public mutating func add(block: Block) {
        blocks.append(block)
    }
    
    public func data(using encoding: String.Encoding) -> [Data] {
        
        var ds = blocks.map { Data.reset + $0.data(using: encoding) }
        
        if feedLinesOnHead > 0 {
            ds.insert(Data(esc_pos: .printAndFeed(lines: feedLinesOnHead)), at: 0)
        }
        
        if feedLinesOnTail > 0 {
            ds.append(Data(esc_pos: .printAndFeed(lines: feedLinesOnTail)))
        }
        
        return ds
    }
}
