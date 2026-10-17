//
//  PrinterError.swift
//  Printer
//
//  Created by gix on 12/12/16.
//  Copyright © 2016 Kevin. All rights reserved.
//

import Foundation

public enum PError: Error {
    /// Bluetooth is off / not authorized, or no printer is connected.
    case deviceNotReady
    case connectFailed
    /// The printer disconnected while data was still being sent.
    case disconnected
    /// The printer exposes no writable characteristic.
    case notSupported
    /// The peripheral reported an error while writing.
    case writeFailed(Error)
}
