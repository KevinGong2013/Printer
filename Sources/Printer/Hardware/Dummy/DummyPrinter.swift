//
//  Dummy.swift
//  Printer
//
//  Created by gix on 2019/7/29.
//  Copyright © 2019 Kevin. All rights reserved.
//

import Foundation

public class DummyPrinter {
    
    public init() {}
    
    public func print(_ value: ESCPOSCommandsCreator) {
        let data = value.data(using: .utf8)
        for d in data {
            debugPrint(d.reduce("", { $0 + String(format: "%d ", $1)}))
        }
    }
}
