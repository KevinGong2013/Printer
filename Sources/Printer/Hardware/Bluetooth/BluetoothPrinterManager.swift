//
//  PrinterManager.swift
//  Printer
//
//  Created by gix on 12/8/16.
//  Copyright © 2016 Kevin. All rights reserved.
//

import CoreBluetooth
import Foundation

private extension CBPeripheral {
    var printerState: BluetoothPrinter.State {
        switch state {
        case .disconnected:
            return .disconnected
        case .connected:
            return .connected
        case .connecting:
            return .connecting
        case .disconnecting:
            return .disconnecting
        @unknown default:
            return .disconnected
        }
    }
}

public struct BluetoothPrinter {
    public enum State {
        case disconnected
        case connecting
        case connected
        case disconnecting
    }

    public let name: String?
    public let identifier: UUID

    public var state: State

    public var isConnecting: Bool {
        return state == .connecting
    }

    init(_ peripheral: CBPeripheral) {
        self.name = peripheral.name
        self.identifier = peripheral.identifier
        self.state = peripheral.printerState
    }
}

public enum NearbyPrinterChange {
    case add(BluetoothPrinter)
    case update(BluetoothPrinter)
    case remove(UUID) // identifier
}

public protocol PrinterManagerDelegate: NSObjectProtocol {
    func nearbyPrinterDidChange(_ change: NearbyPrinterChange)
}

public extension BluetoothPrinterManager {
    static var specifiedServices: Set<String> = ["E7810A71-73AE-499D-8C15-FAA9AEF0C3F2"]
    static var specifiedCharacteristics: Set<String>?
}

public class BluetoothPrinterManager {
    public var updateHandler: (() -> Void)?

    private let queue = DispatchQueue(label: "com.kevin.gong.printer")

    private let centralManager: CBCentralManager

    private let centralManagerDelegate = BluetoothCentralManagerDelegate(BluetoothPrinterManager.specifiedServices)

    private let peripheralDelegate = BluetoothPeripheralDelegate(
        BluetoothPrinterManager.specifiedServices,
        characteristics: BluetoothPrinterManager.specifiedCharacteristics)

    public weak var delegate: PrinterManagerDelegate?

    public var errorReport: ((PError) -> Void)?

    private var connectTimer: Timer?

    public var nearbyPrinters: [BluetoothPrinter] {
        return centralManagerDelegate.discoveredPeripherals.values.map { BluetoothPrinter($0) }
    }

    public init(delegate: PrinterManagerDelegate? = nil) {
        self.centralManager = CBCentralManager(delegate: centralManagerDelegate, queue: queue)

        self.delegate = delegate

        commonInit()
    }

    private func commonInit() {
        peripheralDelegate.wellDoneCanWriteData = { [weak self] in
            self?.connectTimer?.invalidate()
            self?.connectTimer = nil

            self?.nearbyPrinterDidChange(.update(BluetoothPrinter($0)))
        }

        centralManagerDelegate.peripheralDelegate = peripheralDelegate

        centralManagerDelegate.addedPeripherals = { [weak self] in

            guard let printer = (self?.centralManagerDelegate[$0].map { BluetoothPrinter($0) }) else {
                return
            }
            self?.nearbyPrinterDidChange(.add(printer))
        }

        centralManagerDelegate.updatedPeripherals = { [weak self] in
            guard let printer = (self?.centralManagerDelegate[$0].map { BluetoothPrinter($0) }) else {
                return
            }
            self?.nearbyPrinterDidChange(.update(printer))
        }

        centralManagerDelegate.removedPeripherals = { [weak self] in
            self?.nearbyPrinterDidChange(.remove($0))
        }

        ///
        centralManagerDelegate.centralManagerDidUpdateState = { [weak self] in
            guard let `self` = self else {
                return
            }

            guard $0.state == .poweredOn else {
                return
            }
            if let error = self.startScan() {
                self.errorReport?(error)
            }
        }

        centralManagerDelegate.centralManagerDidDisConnectPeripheralWithError = { [weak self] _, peripheral, _ in

            guard let `self` = self else {
                return
            }

            self.nearbyPrinterDidChange(.update(BluetoothPrinter(peripheral)))
            self.peripheralDelegate.disconnect(peripheral)
        }

        centralManagerDelegate.centralManagerDidFailToConnectPeripheralWithError = { [weak self] _, _, err in

            guard let `self` = self else {
                return
            }

            if let error = err {
                debugPrint(error.localizedDescription)
            }

            self.errorReport?(.connectFailed)
        }
    }

    private func nearbyPrinterDidChange(_ change: NearbyPrinterChange) {
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.nearbyPrinterDidChange(change)
            self?.updateHandler?()
        }
    }

    private func deliverError(_ error: PError) {
        DispatchQueue.main.async { [weak self] in
            self?.errorReport?(error)
        }
    }

    public func startScan() -> PError? {
        guard !centralManager.isScanning else {
            return nil
        }

        guard centralManager.state == .poweredOn else {
            return .deviceNotReady
        }

        let serviceUUIDs = BluetoothPrinterManager.specifiedServices.map { CBUUID(string: $0) }
        centralManager.scanForPeripherals(withServices: serviceUUIDs, options: nil)

        return nil
    }

    public func stopScan() {
        centralManager.stopScan()
    }

    public func connect(_ printer: BluetoothPrinter) {
        guard let per = centralManagerDelegate[printer.identifier],
              printer.state == .disconnected || printer.state == .disconnecting
        else {
            return
        }

        var p = printer
        p.state = .connecting
        nearbyPrinterDidChange(.update(p))

        if let t = connectTimer {
            t.invalidate()
        }

        connectTimer = Timer(timeInterval: 15,
                             target: self,
                             selector: #selector(connectTimeout(_:)),
                             userInfo: p.identifier,
                             repeats: false)
        if let t = connectTimer {
            RunLoop.main.add(t, forMode: .default)
        }

        centralManager.connect(per, options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey: true])
    }

    @objc private func connectTimeout(_ timer: Timer) {
        guard let uuid = (timer.userInfo as? UUID), let p = centralManagerDelegate[uuid] else {
            return
        }

        var printer = BluetoothPrinter(p)
        printer.state = .disconnected
        nearbyPrinterDidChange(.update(printer))

        centralManager.cancelPeripheralConnection(p)

        connectTimer?.invalidate()
        connectTimer = nil
    }

    public func disconnect(_ printer: BluetoothPrinter) {
        guard let per = centralManagerDelegate[printer.identifier] else {
            return
        }

        var p = printer
        p.state = .disconnecting
        nearbyPrinterDidChange(.update(p))

        centralManager.cancelPeripheralConnection(per)
    }

    public func disconnectAllPrinter() {
        let serviceUUIDs = BluetoothPrinterManager.specifiedServices.map { CBUUID(string: $0) }

        centralManager.retrieveConnectedPeripherals(withServices: serviceUUIDs).forEach {
            centralManager.cancelPeripheralConnection($0)
        }
    }

    public var canPrint: Bool {
        if peripheralDelegate.writableCharacteristic == nil || peripheralDelegate.writablePeripheral == nil {
            return false
        } else {
            return true
        }
    }

    public var printer: BluetoothPrinter? {
        guard let p = peripheralDelegate.writablePeripheral else {
            return nil
        }

        return BluetoothPrinter(p)
    }

    public func write(_ data: Data, completeBlock: ((PError?) -> Void)? = nil) {
        guard let p = peripheralDelegate.writablePeripheral, let c = peripheralDelegate.writableCharacteristic else {
            completeBlock?(.deviceNotReady)
            return
        }

        // 支持分片发送
        p.writeValue(Data(data), for: c, type: .withoutResponse)

        completeBlock?(nil)
    }

    deinit {
        connectTimer?.invalidate()
        connectTimer = nil

        disconnectAllPrinter()
    }
}
