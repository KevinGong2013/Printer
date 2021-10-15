//
//  DividingBlock.swift
//  Ticket
//
//  Created by gix on 2019/6/30.
//  Copyright © 2019 gix. All rights reserved.
//

import Foundation

public protocol DividingPrivoider {
    func character(for current: Int, total: Int) -> Character
}

extension Character: DividingPrivoider {
    public func character(for current: Int, total: Int) -> Character {
        return self
    }
}

/// add Dividing on receipt
public struct Dividing: BlockDataProvider {
    
    let provider: DividingPrivoider
    
    let printDensity: Int
    let fontDensity: Int
    
    static var `default`: Dividing {
        return Dividing(provider: Character("-"), printDensity: 384, fontDensity: 12)
    }
    
    public func data(using encoding: String.Encoding) -> Data {
        let num = printDensity / fontDensity
        
        let content = stride(from: 0, to: num, by: 1).map { String(provider.character(for: $0, total: num) ) }.joined()
        
        return Text(content).data(using: encoding)
    }
}

