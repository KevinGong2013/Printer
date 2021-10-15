//  ImageBlock.swift
//  Printer
//
//  Created by Pradeep Sakharelia on 18/05/2019.
//  Copyright © 2019 Quick Key Business Solutions. All rights reserved.
//

import Foundation

public struct TicketImage: BlockDataProvider {
    
    private let image: Image
    private let attributes: [Attribute]?
    
    public init(_ image: Image, attributes: [Attribute]? = nil) {
        self.image = image
        self.attributes = attributes
    }
    
    public func data(using encoding: String.Encoding) -> Data {
        var result = Data()
       
        if let attrs = attributes {
            result.append(Data(attrs.flatMap { $0.attribute }))
        }
        
        if let data = image.ticketData {
            result.append(data)
        }
        
        return result
    }
}

public extension TicketImage {
    
    enum PredefinedAttribute: Attribute {
        
        case alignment(NSTextAlignment)
        
        public var attribute: [UInt8] {
            switch self {
            case let .alignment(v):
                return ESC_POSCommand.justification(v == .left ? 0 : v == .center ? 1 : 2).rawValue
            }
        }
    }
    
}
