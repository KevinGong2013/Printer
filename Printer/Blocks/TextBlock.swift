//
//  TextBlock.swift
//  Printer
//
//  Created by gix on 2019/4/10.
//  Copyright © 2019 Kevin. All rights reserved.
//

import Foundation

public protocol Attribute {
    var attribute: [UInt8] { get }
}

public enum PredefinedAttribute: Attribute {
    
    public enum ScaleLevel: UInt8 {
        
        case l0 = 0x00
        case l1 = 0x11
        case l2 = 0x22
        case l3 = 0x33
        case l4 = 0x44
        case l5 = 0x55
        case l6 = 0x66
        case l7 = 0x77
    }
    
    case alignment(NSTextAlignment)
    case bold
    case small
    case light
    case scale(ScaleLevel)
    case feed(UInt8)
    
    public var attribute: [UInt8] {
        switch self {
        case let .alignment(v):
            return ESC_POSCommand.justification(v == .left ? 0 : v == .center ? 1 : 2).rawValue
        case .bold:
            return ESC_POSCommand.emphasize(mode: true).rawValue
        case .small:
            return ESC_POSCommand.font(1).rawValue
        case .light:
            return ESC_POSCommand.color(n: 1).rawValue
        case let .scale(v):
            return [0x1D, 0x21, v.rawValue]
        case let .feed(v):
            return ESC_POSCommand.feed(points: v).rawValue
        }
    }
}

public struct TextBlock: PrintableBlock {
    
    let content: String
    let attributes: [Attribute]?
    
    public init(_ content: String, attributes: [Attribute]? = nil) {
        self.content = content
        self.attributes = attributes
    }
    
    public func data(using encoding: String.Encoding) -> Data {
        var result = Data()
        
        if let attrs = attributes {
            result.append(Data(attrs.flatMap { $0.attribute }))
        }
        
        if let cd = content.data(using: encoding) {
            result.append(cd)
        }
        
        return result
    }
}

public extension TextBlock {
    init(content: String, predefined attributes: PredefinedAttribute...) {
        self.init(content, attributes: attributes)
    }
}

public extension TextBlock {
    
    static func title(_ content: String) -> TextBlock {
        return TextBlock(content: content, predefined: .scale(.l1), .alignment(.center))
    }
    
    static func kv(printDensity: Int = 384, fontDensity: Int = 12, k: String, v: String, attributes: [Attribute]? = nil) -> TextBlock {
        
        var num = printDensity / fontDensity
        
        let string = k + v
        
        for c in string {
            if (c >= "\u{2E80}" && c <= "\u{FE4F}") || c == "\u{FFE5}"{
                num -= 2
            } else  {
                num -= 1
            }
        }
        
        var contents = stride(from: 0, to: num, by: 1).map { _ in " " }
        
        contents.insert(k, at: 0)
        contents.append(v)
        
        return TextBlock(contents.joined(), attributes: attributes)
    }
}
