//
//  BluetoothCentralManagerDelegate.swift
//  Printer
//
//  Created by gix on 12/8/16.
//  Copyright © 2016 Kevin. All rights reserved.
//

import CoreBluetooth
import Foundation

class BluetoothCentralManagerDelegate: NSObject, CBCentralManagerDelegate {
    enum UserDefaultKey {
        static let autoConnectUUID = "auto.connect.uuid"
    }

    private var services = Set<CBUUID>()

    var peripheralDelegate: BluetoothPeripheralDelegate?

    var centralManagerDidUpdateState: ((CBCentralManager) -> Void)?
    var centralManagerDidDiscoverPeripheralWithAdvertisementDataAndRSSI:
        ((CBCentralManager, CBPeripheral, [String: Any], NSNumber) -> Void)?
    var centralManagerDidConnectPeripheral: ((CBCentralManager, CBPeripheral) -> Void)?
    var centralManagerDidFailToConnectPeripheralWithError: ((CBCentralManager, CBPeripheral, Error?) -> Void)?
    var centralManagerDidDisConnectPeripheralWithError: ((CBCentralManager, CBPeripheral, Error?) -> Void)?

    typealias PeripheralChangeBlock = (UUID) -> Void

    var addedPeripherals: PeripheralChangeBlock?
    var updatedPeripherals: PeripheralChangeBlock?
    var removedPeripherals: PeripheralChangeBlock?

    private var _discoveredPeripherals: [UUID: CBPeripheral] = [:]
    private let lock = NSLock()

    var discoveredPeripherals: [UUID: CBPeripheral] {
        lock.lock(); defer { lock.unlock() }
        return _discoveredPeripherals
    }

    subscript(uuid: UUID) -> CBPeripheral? {
        get {
            lock.lock(); defer { lock.unlock() }
            return _discoveredPeripherals[uuid]
        }
        set {
            lock.lock()
            let oldValue = _discoveredPeripherals[uuid]
            _discoveredPeripherals[uuid] = newValue
            lock.unlock()

            if newValue == nil {
                if oldValue != nil {
                    removedPeripherals?(uuid)
                }
            } else {
                if oldValue == nil {
                    addedPeripherals?(uuid)
                } else {
                    updatedPeripherals?(uuid)
                }
            }
        }
    }

    convenience init(_ services: Set<String>) {
        self.init()
        self.services = Set(services.map { CBUUID(string: $0) })
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        centralManagerDidUpdateState?(central)

        guard central.state == .poweredOn, !services.isEmpty else {
            return
        }

        // Adopt peripherals the system already has connected (e.g. from a previous launch).
        let known = Array(services)
        for retrieveConnectedPeripheral in central.retrieveConnectedPeripherals(withServices: known) {
            self[retrieveConnectedPeripheral.identifier] = retrieveConnectedPeripheral
            retrieveConnectedPeripheral.delegate = peripheralDelegate
            retrieveConnectedPeripheral.discoverServices(known)
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber)
    {
        if let isConnectable = advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber,
           isConnectable.boolValue == false
        {
            return
        }

        if !services.isEmpty {
            var advertised = Set((advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]) ?? [])
            advertised.formUnion((advertisementData[CBAdvertisementDataOverflowServiceUUIDsKey] as? [CBUUID]) ?? [])
            guard !advertised.isDisjoint(with: services) else {
                return
            }
        }

        self[peripheral.identifier] = peripheral

        if let uuid = UserDefaults.standard.string(forKey: UserDefaultKey.autoConnectUUID),
           peripheral.identifier.uuidString == uuid, peripheral.state == .disconnected
        {
            central.connect(peripheral, options: nil)
        }

        centralManagerDidDiscoverPeripheralWithAdvertisementDataAndRSSI?(central, peripheral, advertisementData, RSSI)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        centralManagerDidConnectPeripheral?(central, peripheral)

        peripheral.delegate = peripheralDelegate
        peripheral.discoverServices(services.isEmpty ? nil : Array(services))

        // Remember the printer for auto-connect next time.
        UserDefaults.standard.set(peripheral.identifier.uuidString, forKey: UserDefaultKey.autoConnectUUID)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        centralManagerDidFailToConnectPeripheralWithError?(central, peripheral, error)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        centralManagerDidDisConnectPeripheralWithError?(central, peripheral, error)
    }
}
