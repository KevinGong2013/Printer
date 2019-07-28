//
//  Delegate.swift
//  Printer
//
//  Created by gix on 12/8/16.
//  Copyright © 2016 Kevin. All rights reserved.
//

import Foundation
import CoreBluetooth

class BluetoothCentralManagerDelegate: NSObject, CBCentralManagerDelegate {

    struct UserDefaultKey {

        static let autoConectUUID = "auto.connect.uuid"
    }

    private var services: Set<String>!

    var peripheralDelegate: BluetoothPeripheralDelegate?

    open var centralManagerDidUpdateState: ((CBCentralManager) -> ())?
    open var centralManagerDidDiscoverPeripheralWithAdvertisementDataAndRSSI: ((CBCentralManager, CBPeripheral, [String : Any], NSNumber) -> ())?
    open var centralManagerDidConnectPeripheral: ((CBCentralManager, CBPeripheral) -> ())?
    open var centralManagerDidFailToConnectPeripheralWithError: ((CBCentralManager, CBPeripheral, Error?) -> ())?
    open var centralManagerDidDisConnectPeripheralWithError: ((CBCentralManager, CBPeripheral, Error?) -> ())?

    typealias PeripheralChangeBlock = (UUID) -> ()

    var addedPeripherals: PeripheralChangeBlock?
    var updatedPeripherals: PeripheralChangeBlock?
    var removedPeripherals: PeripheralChangeBlock?

    private(set) var discoveredPeripherals: [UUID: CBPeripheral] = [:]
    private let lock = NSLock()

    subscript(uuid: UUID) -> CBPeripheral? {
        get {
            lock.lock(); defer { lock.unlock() }
            return discoveredPeripherals[uuid]
        }
        set {

            let oldValue = discoveredPeripherals[uuid]?.identifier

            lock.lock()
            discoveredPeripherals[uuid] = newValue
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
        self.services = services
    }

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {

        centralManagerDidUpdateState?(central)

        let ss = services.map { CBUUID(string: $0) }

        // discover services for connected per.
        central.retrieveConnectedPeripherals(withServices: ss).forEach {
            $0.delegate = peripheralDelegate
            $0.discoverServices(ss)
        }
    }

    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {

        guard let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID],
            let isConnectable = advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber,
            serviceUUIDs.count > 0, isConnectable == 1 else {
                return
        }

        // if peripheral doesn't container specified services, ignore.
        let peripheralServiceSet = Set(serviceUUIDs.map { $0.uuidString } )

        guard peripheralServiceSet.intersection(services).count > 0 else {

            return
        }

        self[peripheral.identifier] = peripheral

        if let uuid = UserDefaults.standard.object(forKey: UserDefaultKey.autoConectUUID) as? String {
            if peripheral.identifier.uuidString == uuid {
                central.connect(peripheral, options: nil)
            }
        }

        centralManagerDidDiscoverPeripheralWithAdvertisementDataAndRSSI?(central, peripheral, advertisementData, RSSI)
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {

        centralManagerDidConnectPeripheral?(central, peripheral)

        peripheral.delegate = peripheralDelegate
        peripheral.discoverServices(services.map { CBUUID(string: $0) })

        // 保存已连接的uuid
        UserDefaults.standard.set(peripheral.identifier.uuidString, forKey: UserDefaultKey.autoConectUUID)
        UserDefaults.standard.synchronize()
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {

        centralManagerDidFailToConnectPeripheralWithError?(central, peripheral, error)
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {

        centralManagerDidDisConnectPeripheralWithError?(central, peripheral, error)
    }
}
