//
//  DividingBlock.swift
//  Printer
//
//  Created by gix on 2019/4/10.
//  Copyright © 2019 Kevin. All rights reserved.
//

import Foundation

public protocol DividingPrivoider {
    func character(for current: Int, total: Int) -> Character
}

enum Hyphen: DividingPrivoider {
    case `default`
    
    func character(for current: Int, total: Int) -> Character {
        return "-"
    }
}

public struct DividingBlock: PrintableBlock {
    
    let provider: DividingPrivoider
    
    let printDensity: Int
    let fontDensity: Int
    
    static var `default`: DividingBlock {
        return DividingBlock(provider: Hyphen.default, printDensity: 384, fontDensity: 12)
    }
    
    public func data(using encoding: String.Encoding) -> Data {
        let num = printDensity / fontDensity
        
        let content = stride(from: 0, to: num, by: 1).map { String(provider.character(for: $0, total: num) ) }.joined()
        
        return TextBlock(content).data(using: encoding)
    }
}
