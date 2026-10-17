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
    private var preferredCharacteristics = [CBUUID]()
    private var candidates = [CBCharacteristic]()

    /// Called once a characteristic that accepts writes has been found.
    var wellDoneCanWriteData: ((CBPeripheral) -> Void)?
    /// Called when all services were discovered but none has a writable characteristic.
    var noWritableCharacteristic: ((CBPeripheral) -> Void)?
    /// `peripheralIsReady(toSendWriteWithoutResponse:)`
    var readyToWrite: ((CBPeripheral) -> Void)?
    /// `didWriteValueFor` (only for `.withResponse` writes)
    var didWrite: ((CBPeripheral, Error?) -> Void)?
    /// Human readable trace of service / characteristic discovery and notifications.
    var diagnostics: ((String) -> Void)?

    private(set) var writablePeripheral: CBPeripheral?
    private(set) var writableCharacteristic: CBCharacteristic?

    private var pendingServices = 0

    convenience init(_ services: Set<String>, characteristics: [String]) {
        self.init()
        self.services = Set(services.map { CBUUID(string: $0) })
        preferredCharacteristics = characteristics.map { CBUUID(string: $0) }
    }

    func disconnect(_ peripheral: CBPeripheral) {
        guard let wp = writablePeripheral else {
            return
        }

        if wp.identifier == peripheral.identifier {
            writablePeripheral = nil
            writableCharacteristic = nil
            candidates.removeAll()
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            diagnostics?("discoverServices failed: \(error.localizedDescription)")
        }
        guard error == nil, let found = peripheral.services else {
            return
        }
        diagnostics?("services: " + found.map(\.uuid.uuidString).joined(separator: ", "))

        let matching = services.isEmpty ? found : found.filter { services.contains($0.uuid) }
        candidates.removeAll()
        pendingServices = matching.count
        guard !matching.isEmpty else {
            noWritableCharacteristic?(peripheral)
            return
        }
        matching.forEach { peripheral.discoverCharacteristics(nil, for: $0) }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        pendingServices -= 1

        let characteristics = service.characteristics ?? []
        if let error {
            diagnostics?("discoverCharacteristics(\(service.uuid)) failed: \(error.localizedDescription)")
        }
        diagnostics?("service \(service.uuid): " + characteristics.map { "\($0.uuid) [\($0.properties.printerDescription)]" }.joined(separator: ", "))

        let writable = characteristics.filter {
            $0.properties.contains(.writeWithoutResponse) || $0.properties.contains(.write)
        }
        candidates += writable.filter { c in !candidates.contains { $0.uuid == c.uuid && $0.service?.uuid == c.service?.uuid } }

        // Wait until every matching service reported back, then pick the best candidate
        // (a printer may expose several serial-port services; the first to answer is not
        // necessarily the one that feeds the print engine).
        guard pendingServices <= 0 else { return }

        guard let pick = bestCandidate() else {
            noWritableCharacteristic?(peripheral)
            return
        }
        use(pick, on: peripheral)
    }

    /// Every characteristic that accepts writes, across all matching services.
    var writableCandidates: [CBCharacteristic] { candidates }

    /// Switch the write target to one of `writableCandidates`.
    func select(characteristicUUID: CBUUID, serviceUUID: CBUUID?, on peripheral: CBPeripheral) -> Bool {
        guard let pick = candidates.first(where: {
            $0.uuid == characteristicUUID && (serviceUUID == nil || $0.service?.uuid == serviceUUID)
        }) else { return false }
        use(pick, on: peripheral)
        return true
    }

    private func bestCandidate() -> CBCharacteristic? {
        for uuid in preferredCharacteristics {
            if let c = candidates.first(where: { $0.uuid == uuid }) { return c }
        }
        return candidates.first { $0.properties.contains(.writeWithoutResponse) } ?? candidates.first
    }

    private func use(_ pick: CBCharacteristic, on peripheral: CBPeripheral) {
        diagnostics?("using characteristic \(pick.uuid) [\(pick.properties.printerDescription)] of service \(pick.service?.uuid.uuidString ?? "?"); MTU withoutResponse=\(peripheral.maximumWriteValueLength(for: .withoutResponse)) withResponse=\(peripheral.maximumWriteValueLength(for: .withResponse))")
        writablePeripheral = peripheral
        writableCharacteristic = pick
        if pick.properties.contains(.notify) {
            peripheral.setNotifyValue(true, for: pick)
        }
        wellDoneCanWriteData?(peripheral)
    }

    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        readyToWrite?(peripheral)
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor _: CBCharacteristic, error: Error?) {
        didWrite?(peripheral, error)
    }

    func peripheral(_: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            diagnostics?("notify \(characteristic.uuid) error: \(error.localizedDescription)")
        } else if let value = characteristic.value {
            diagnostics?("notify \(characteristic.uuid): " + value.map { String(format: "%02X", $0) }.joined(separator: " "))
        }
    }

    func peripheral(_: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        diagnostics?("notifications for \(characteristic.uuid): \(characteristic.isNotifying ? "on" : "off")\(error.map { " (\($0.localizedDescription))" } ?? "")")
    }
}

extension CBCharacteristicProperties {
    var printerDescription: String {
        var parts = [String]()
        if contains(.read) { parts.append("read") }
        if contains(.write) { parts.append("write") }
        if contains(.writeWithoutResponse) { parts.append("writeNoRsp") }
        if contains(.notify) { parts.append("notify") }
        if contains(.indicate) { parts.append("indicate") }
        return parts.joined(separator: "|")
    }
}
