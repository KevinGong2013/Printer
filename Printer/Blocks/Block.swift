//
//  Blocks.swift
//  Printer
//
//  Created by gix on 12/10/16.
//  Updated by Pradeep Sakharelia on 15/05/19
//  Copyright © 2016 Kevin. All rights reserved.
//

import Foundation

public protocol PrintableBlock {
    func data(using encoding: String.Encoding) -> Data
}

public enum Block: PrintableBlock {
    case blank
    case qr(String)
    case title(String)
    case text(TextBlock)
    case kv(key: String, value: String)
    case dividing
    case image(UIImage, attributes: [Attribute]?) //  Updated by Pradeep Sakharelia on 15/05/19
    case custom(block: PrintableBlock)
    
    public func data(using encoding: String.Encoding) -> Data {
        switch self {
        case .blank:
            return Data()
        case .qr(let content):
            return QRBlock(content).data(using: encoding)
        case .title(let title):
            return TextBlock.title(title).data(using: encoding)
        case .text(let block):
            return block.data(using: encoding)
        case .kv(let key, let value):
            return TextBlock.kv(k: key, v: value).data(using: encoding)
        case .dividing:
            return DividingBlock.default.data(using: encoding)
        case .image(let img, let attributes): //  Updated by Pradeep Sakharelia on 15/05/19
            return ImageBlock(img, attributes: attributes).data(using: encoding)
        case .custom(let b):
            return b.data(using: encoding)
        }
    }
}


