//
//  Dummy.swift
//  Printer
//
//  Created by gix on 2019/7/29.
//  Copyright © 2019 Kevin. All rights reserved.
//

import Foundation

// For debug

public protocol TicketRender: NSObject {
    
    func printerDidGenerate(_ printer: DummyPrinter, html htmlTicket: String)
}

public class DummyPrinter {
    
    public weak var ticketRender: TicketRender?
    
    public init() {}
    
    public func write(_ data: Data) {
        
        let value = data.base64EncodedString()
        
        debugPrint(value)
    }
}
