//
//  Text.swift
//  Printer
//
//  Created by gix on 2023/2/2.
//

import Foundation

extension String: ReceiptItem {
    
    public func assemblePrintableData(_ profile: PrinterProfile) -> [UInt8] {
        guard let data = self.data(using: profile.encoding) else {
            return []
        }
        
        return Array<UInt8>(data) + Command.CursorPosition.lineFeed.value
    }
}

public struct KV: ReceiptItem {
    
    public let k: String
    public let v: String
    
    public init(_ k: String, _ v: String) {
        self.k = k
        self.v = v
    }
    
    public func assemblePrintableData(_ profile: PrinterProfile) -> [UInt8] {
        
        var num = profile.maxWidthDensity / profile.fontDesity
        
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
        
        return contents.joined().assemblePrintableData(profile)
    }
}

public protocol DividingPrivoider {
    func character(for current: Int, total: Int) -> Character
}

extension Character: DividingPrivoider {
    public func character(for current: Int, total: Int) -> Character {
        return self
    }
}

public struct Dividing: ReceiptItem {
    
    let provider: DividingPrivoider
    
    public static func `default`(provider: Character = Character("-")) -> Dividing {
        return Dividing(provider: provider)
    }
    
    public func assemblePrintableData(_ profile: PrinterProfile) -> [UInt8] {
        let num = profile.maxWidthDensity / profile.fontDesity
        let content = stride(from: 0, to: num, by: 1).map { String(provider.character(for: $0, total: num) ) }.joined()
        return content.assemblePrintableData(profile)
    }
    
}

/// Any other Text template(s)
///
///
