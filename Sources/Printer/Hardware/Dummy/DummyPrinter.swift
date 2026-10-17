//
//  DummyPrinter.swift
//  Printer
//
//  Created by gix on 2019/7/29.
//  Copyright © 2019 Kevin. All rights reserved.
//

import Foundation

/// A printer that only records what it would have printed. Useful in unit tests
/// and for debugging receipts without hardware.
public class DummyPrinter {
    /// Called with every payload passed to `write(_:)`.
    public var onWrite: ((Data) -> Void)?

    /// Every payload written so far.
    public private(set) var history = [Data]()

    /// When `true` (the default) each payload is also logged as base64 via `debugPrint`.
    public var logsToConsole = true

    public init() {}

    public func write(_ data: Data) {
        history.append(data)
        onWrite?(data)
        if logsToConsole {
            debugPrint(data.base64EncodedString())
        }
    }

    public func write(_ receipt: Receipt) {
        write(receipt.bytes)
    }
}
