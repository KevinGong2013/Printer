//
//  Blocks.swift
//  Printer
//
//  Created by GongXiang on 12/10/16.
//  Copyright © 2016 Kevin. All rights reserved.
//

import Foundation

public protocol Attribute {

    var attribute: [UInt8] { get }
}

public extension String {

    struct Encoding {

        static let GB_18030_2000 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
    }
}

public struct QRBlock: Block {
    
    let content: String
    
    public init(_ content: String) {
        self.content = content
    }
    
    public var data: Data {
        
        var result = Data()
        
        result.append(Data(bytes: ESC_POSCommand.justification(1).rawValue + ESC_POSCommand.QRSetSize().rawValue + ESC_POSCommand.QRSetRecoveryLevel().rawValue + ESC_POSCommand.QRGetReadyToStore(text: content).rawValue))
        
        if let cd = content.data(using: String.Encoding.GB_18030_2000) {
            result.append(cd)
        }
        
        result.append(Data(bytes: ESC_POSCommand.QRPrint().rawValue))
        
        return result
    }
}

public struct TextBlock: Block {

    let content: String
    let attributes: [Attribute]?

    public init(_ content: String, attributes: [Attribute]? = nil) {
        self.content = content
        self.attributes = attributes
    }

    public var data: Data {

        var result = Data()

        if let attrs = attributes {
            result.append(Data(bytes: attrs.flatMap { $0.attribute }))
        }

        if let cd = content.data(using: String.Encoding.GB_18030_2000) {
            result.append(cd)
        }

        return result
    }
}

public extension TextBlock {

    enum PredefinedAttribute: Attribute {

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

    init(content: String, predefined attributes: PredefinedAttribute...) {
        self.init(content, attributes: attributes)
    }
}

public extension TextBlock {

    static func title(_ content: String) -> Block {
        return TextBlock(content: content, predefined: .scale(.l1), .alignment(.center))
    }

    static func kv(printDensity: Int = 384, fontDensity: Int = 12, k: String, v: String, attributes: [Attribute]? = nil) -> Block {

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

    static func dividing(printDensity: Int = 384, fontDensity: Int = 12, separatorProvider: @escaping ((Int, Int) -> Character) = { _, _ in "-"}) -> Block {

        let num = printDensity / fontDensity

        let content = stride(from: 0, to: num, by: 1).map { String(separatorProvider($0, num)) }.joined()

        return TextBlock(content)
    }
}

public struct BlockConstructor {

    internal let content: Any

    public init(_ content: Any) {
        self.content = content
    }
    
    public var qr: Block {
        return QRBlock(String(describing: content))
    }

    public var title: Block {
        return TextBlock.title(String(describing: content))
    }

    public var text: Block {
        return TextBlock(String(describing: content))
    }

    public var dividing: Block {

        if let c = content as? Character {
            return TextBlock.dividing() { _, _ in
                return c
            }
        } else {
            return TextBlock.dividing()
        }
    }

    public func blank(_ l: UInt8 = 1) -> Block {
        return Data()
    }

    public func kv(k: String, v: String, attributes: [TextBlock.PredefinedAttribute]? = nil) -> Block {
        return TextBlock.kv(k: k, v: v, attributes: attributes)
    }
}

public extension String {

    var bc: BlockConstructor {
        return BlockConstructor(self)
    }
}

public extension Character {

    var bc: BlockConstructor {
        return BlockConstructor(self)
    }
}

public extension Int {

    var bc: BlockConstructor {
        return BlockConstructor(self)
    }
}

public extension Double {

    var bc: BlockConstructor {
        return BlockConstructor(self)
    }
}
