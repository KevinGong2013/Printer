//
//  BluetoothPeripheralDelegate.swift
//  Printer
//
//  Created by gix on 12/8/16.
//  Copyright © 2016 Kevin. All rights reserved.
//

import CoreBluetooth
import Foundation

class BluetoothPeripheralDelegate: NSObject, CBPeripheralDelegate {
    private var services = Set<CBUUID>()
    private var preferredCharacteristics = Set<CBUUID>()

    /// Called once a characteristic that accepts writes has been found.
    var wellDoneCanWriteData: ((CBPeripheral) -> Void)?
    /// Called when all services were discovered but none has a writable characteristic.
    var noWritableCharacteristic: ((CBPeripheral) -> Void)?
    /// `peripheralIsReady(toSendWriteWithoutResponse:)`
    var readyToWrite: ((CBPeripheral) -> Void)?
    /// `didWriteValueFor` (only for `.withResponse` writes)
    var didWrite: ((CBPeripheral, Error?) -> Void)?

    private(set) var writablePeripheral: CBPeripheral?
    private(set) var writableCharacteristic: CBCharacteristic?

    private var pendingServices = 0

    convenience init(_ services: Set<String>, characteristics: Set<String>?) {
        self.init()
        self.services = Set(services.map { CBUUID(string: $0) })
        preferredCharacteristics = Set((characteristics ?? []).map { CBUUID(string: $0) })
    }

    func disconnect(_ peripheral: CBPeripheral) {
        guard let wp = writablePeripheral else {
            return
        }

        if wp.identifier == peripheral.identifier {
            writablePeripheral = nil
            writableCharacteristic = nil
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil, let found = peripheral.services else {
            return
        }

        let candidates = services.isEmpty ? found : found.filter { services.contains($0.uuid) }
        pendingServices = candidates.count
        guard !candidates.isEmpty else {
            noWritableCharacteristic?(peripheral)
            return
        }
        candidates.forEach { peripheral.discoverCharacteristics(nil, for: $0) }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error _: Error?) {
        pendingServices -= 1

        // Keep the first usable characteristic; don't let a later, unrelated service replace it.
        if writableCharacteristic != nil, writablePeripheral?.identifier == peripheral.identifier {
            return
        }

        let characteristics = service.characteristics ?? []
        let writable = characteristics.filter {
            $0.properties.contains(.writeWithoutResponse) || $0.properties.contains(.write)
        }

        let pick = writable.first { preferredCharacteristics.contains($0.uuid) }
            ?? writable.first { $0.properties.contains(.writeWithoutResponse) }
            ?? writable.first

        if let pick {
            writablePeripheral = peripheral
            writableCharacteristic = pick
            if pick.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: pick)
            }
            wellDoneCanWriteData?(peripheral)
        } else if pendingServices <= 0 {
            noWritableCharacteristic?(peripheral)
        }
    }

    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        readyToWrite?(peripheral)
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor _: CBCharacteristic, error: Error?) {
        didWrite?(peripheral, error)
    }

    func peripheral(_: CBPeripheral, didUpdateValueFor _: CBCharacteristic, error _: Error?) {
        // Status bytes from the printer (paper out etc.) arrive here. Not surfaced yet.
    }
}
