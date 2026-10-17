//
//  BluetoothPrinterManager.swift
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
        state == .connecting
    }

    init(_ peripheral: CBPeripheral) {
        name = peripheral.name
        identifier = peripheral.identifier
        state = peripheral.printerState
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
    /// GATT services that identify a printer. Set this **before** creating the manager.
    /// An empty set scans for every connectable peripheral.
    ///
    /// Defaults cover the common serial-port-over-BLE profiles:
    /// - `E7810A71-…` Gprinter / Xprinter / Munbyn (ESC/POS BLE module)
    /// - `49535343-…` Microchip ISSC (many 58 mm "mini" printers, GoojPRT, PT-210)
    /// - `18F0` Epson / generic "printer" service
    /// - `FFE0`, `FF00` HM-10 / Telink style UART bridges
    static var specifiedServices: Set<String> = [
        "E7810A71-73AE-499D-8C15-FAA9AEF0C3F2",
        "49535343-FE7D-4AE5-8FA9-9FAFD205E455",
        "18F0",
        "FFE0",
        "FF00",
    ]

    /// Preferred write characteristics, tried in order of discovery. When none of these
    /// is present the first characteristic with a write property is used.
    static var specifiedCharacteristics: Set<String>? = [
        "BEF8D6C9-9C21-4C9E-B632-BD58C1009F9F",
        "49535343-8841-43F4-A8D4-ECBE34729BB3",
        "2AF1",
        "FFE1",
        "FF02",
    ]
}

public class BluetoothPrinterManager {
    public var updateHandler: (() -> Void)?

    private let queue = DispatchQueue(label: "com.kevin.gong.printer")

    private let centralManager: CBCentralManager

    private let centralManagerDelegate = BluetoothCentralManagerDelegate(BluetoothPrinterManager.specifiedServices)

    private let peripheralDelegate = BluetoothPeripheralDelegate(
        BluetoothPrinterManager.specifiedServices,
        characteristics: BluetoothPrinterManager.specifiedCharacteristics
    )

    public weak var delegate: PrinterManagerDelegate?

    public var errorReport: ((PError) -> Void)?

    /// Maximum bytes per BLE write. `0` (default) uses the negotiated MTU.
    /// Lower it (e.g. 100) for printers that garble long images.
    public var writeChunkSize: Int = 0

    /// Pause between chunks. Some cheap printers cannot drain their buffer as fast as
    /// BLE delivers; a few milliseconds here removes white lines in images.
    public var interChunkDelay: TimeInterval = 0

    private var connectTimer: Timer?

    private var pendingWrites = [WriteJob]()
    private var writeInFlight = false

    public var nearbyPrinters: [BluetoothPrinter] {
        centralManagerDelegate.discoveredPeripherals.values.map { BluetoothPrinter($0) }
    }

    public init(delegate: PrinterManagerDelegate? = nil) {
        centralManager = CBCentralManager(delegate: centralManagerDelegate, queue: queue)

        self.delegate = delegate

        commonInit()
    }

    private func commonInit() {
        peripheralDelegate.wellDoneCanWriteData = { [weak self] in
            self?.connectTimer?.invalidate()
            self?.connectTimer = nil

            self?.nearbyPrinterDidChange(.update(BluetoothPrinter($0)))
        }

        peripheralDelegate.noWritableCharacteristic = { [weak self] _ in
            self?.deliverError(.notSupported)
        }

        peripheralDelegate.readyToWrite = { [weak self] _ in
            self?.queue.async { self?.pumpWrites() }
        }

        peripheralDelegate.didWrite = { [weak self] _, error in
            self?.queue.async {
                self?.writeInFlight = false
                if let error {
                    self?.failPendingWrites(.writeFailed(error))
                } else {
                    self?.pumpWrites()
                }
            }
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
            guard let self else {
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

            guard let self else {
                return
            }

            self.nearbyPrinterDidChange(.update(BluetoothPrinter(peripheral)))
            self.peripheralDelegate.disconnect(peripheral)
            self.queue.async { self.failPendingWrites(.disconnected) }
        }

        centralManagerDelegate.centralManagerDidFailToConnectPeripheralWithError = { [weak self] _, _, err in

            guard let self else {
                return
            }

            if let error = err {
                debugPrint(error.localizedDescription)
            }

            self.deliverError(.connectFailed)
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
        centralManager.scanForPeripherals(withServices: serviceUUIDs.isEmpty ? nil : serviceUUIDs, options: nil)

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

        for retrieveConnectedPeripheral in centralManager.retrieveConnectedPeripherals(withServices: serviceUUIDs) {
            centralManager.cancelPeripheralConnection(retrieveConnectedPeripheral)
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

    /// Sends `data` to the connected printer, split into MTU-sized chunks and paced by the
    /// peripheral's flow control. `completeBlock` is called on the main queue once every
    /// chunk has been handed to CoreBluetooth, or immediately with an error.
    public func write(_ data: Data, completeBlock: ((PError?) -> Void)? = nil) {
        guard let p = peripheralDelegate.writablePeripheral, let c = peripheralDelegate.writableCharacteristic else {
            completeBlock?(.deviceNotReady)
            return
        }

        let job = WriteJob(data: data, peripheral: p, characteristic: c, completion: completeBlock)
        queue.async { [weak self] in
            self?.pendingWrites.append(job)
            self?.pumpWrites()
        }
    }

    /// Convenience for `write(Data(receipt.data))`.
    public func write(_ receipt: Receipt, completeBlock: ((PError?) -> Void)? = nil) {
        write(receipt.bytes, completeBlock: completeBlock)
    }

    // MARK: - Write queue (runs on `queue`)

    private final class WriteJob {
        let data: Data
        let peripheral: CBPeripheral
        let characteristic: CBCharacteristic
        let completion: ((PError?) -> Void)?
        var offset = 0

        init(data: Data, peripheral: CBPeripheral, characteristic: CBCharacteristic, completion: ((PError?) -> Void)?) {
            self.data = data
            self.peripheral = peripheral
            self.characteristic = characteristic
            self.completion = completion
        }
    }

    private func pumpWrites() {
        while let job = pendingWrites.first {
            guard job.peripheral.state == .connected else {
                failPendingWrites(.disconnected)
                return
            }

            if job.offset >= job.data.count {
                pendingWrites.removeFirst()
                DispatchQueue.main.async { job.completion?(nil) }
                continue
            }

            let withoutResponse = job.characteristic.properties.contains(.writeWithoutResponse)
            let type: CBCharacteristicWriteType = withoutResponse ? .withoutResponse : .withResponse

            if withoutResponse {
                if #available(iOS 11.0, macOS 10.13, *), !job.peripheral.canSendWriteWithoutResponse {
                    return // resumed by `readyToWrite`
                }
            } else if writeInFlight {
                return // resumed by `didWrite`
            }

            var mtu = job.peripheral.maximumWriteValueLength(for: type)
            if mtu <= 0 { mtu = 20 }
            let size = writeChunkSize > 0 ? min(writeChunkSize, mtu) : mtu
            let end = min(job.offset + size, job.data.count)
            let chunk = job.data.subdata(in: job.offset ..< end)
            job.offset = end

            job.peripheral.writeValue(chunk, for: job.characteristic, type: type)
            if !withoutResponse {
                writeInFlight = true
            }

            if interChunkDelay > 0, job.offset < job.data.count {
                queue.asyncAfter(deadline: .now() + interChunkDelay) { [weak self] in self?.pumpWrites() }
                return
            }
        }
    }

    private func failPendingWrites(_ error: PError) {
        let jobs = pendingWrites
        pendingWrites.removeAll()
        writeInFlight = false
        guard !jobs.isEmpty else { return }
        DispatchQueue.main.async {
            jobs.forEach { $0.completion?(error) }
        }
    }

    deinit {
        connectTimer?.invalidate()
        connectTimer = nil

        disconnectAllPrinter()
    }
}
