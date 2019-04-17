//
//  Blocks.swift
//  Printer
//
//  Created by gix on 12/10/16.
//  Copyright © 2016 Kevin. All rights reserved.
//

import Foundation

public protocol PritableBlock {
    func data(using encoding: String.Encoding) -> Data
}

public enum Block: PritableBlock {
    case blank
    case qr(String)
    case title(String)
    case text(TextBlock)
    case kv(key: String, value: String)
    case dividing
    case image(ESCPOSEImage, maxWidth: CGFloat)
    case custom(block: PritableBlock)
    
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
        case .image(let img, let width):
            return ImageBlock(img, maxWidth: width).data(using: encoding)
        case .custom(let b):
            return b.data(using: encoding)
        }
    }
}
