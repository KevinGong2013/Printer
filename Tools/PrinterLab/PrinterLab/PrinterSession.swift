import AppKit
import Combine
import CoreBluetooth
import Foundation
import Printer

struct LogEntry: Identifiable {
    let id = UUID()
    let date = Date()
    let text: String
    let isError: Bool
}

/// Owns the Bluetooth manager and the non-Bluetooth output targets.
final class PrinterSession: ObservableObject {
    enum Target: String, CaseIterable, Identifiable {
        case bluetooth = "Bluetooth LE"
        case network = "Network (TCP 9100)"
        case devicePath = "Serial / device path"
        case file = "Save to file"
        var id: String { rawValue }
    }

    @Published private(set) var printers: [BluetoothPrinter] = []
    @Published private(set) var connected: BluetoothPrinter?
    @Published private(set) var characteristics: [(service: String, characteristic: String)] = []
    @Published var selectedCharacteristic = ""
    @Published private(set) var log: [LogEntry] = []
    @Published private(set) var isSending = false

    @Published var target: Target = .bluetooth
    @Published var devicePath = "/dev/cu.usbserial"
    @Published var baudRate = 9600
    @Published var networkHost = "192.168.1.100"
    @Published var networkPort = 9100
    @Published var chunkSize = 20 { didSet { manager.writeChunkSize = chunkSize } }
    @Published var writeWithResponse = false { didSet { manager.writeType = writeWithResponse ? .withResponse : .automatic } }
    @Published var interChunkDelayMs = 0.0 { didSet { manager.interChunkDelay = interChunkDelayMs / 1000 } }
    @Published var serviceUUIDs = BluetoothPrinterManager.specifiedServices.sorted().joined(separator: "\n")

    private(set) var manager = BluetoothPrinterManager()

    init() {
        bind()
    }

    private func bind() {
        manager.updateHandler = { [weak self] in self?.refresh() }
        manager.errorReport = { [weak self] error in self?.append("Bluetooth error: \(error)", error: true) }
        manager.diagnostics = { [weak self] message in self?.append("ble: \(message)") }
        manager.writeChunkSize = chunkSize
        manager.interChunkDelay = interChunkDelayMs / 1000
        manager.writeType = writeWithResponse ? .withResponse : .automatic
    }

    private func refresh() {
        printers = manager.nearbyPrinters.sorted { ($0.name ?? "~") < ($1.name ?? "~") }
        connected = manager.printer
        characteristics = manager.writableCharacteristics
        selectedCharacteristic = manager.currentCharacteristic.map { "\($0.service)/\($0.characteristic)" } ?? ""
    }

    func connect(_ printer: BluetoothPrinter) {
        append("Connecting to \(printer.name ?? printer.identifier.uuidString)…")
        manager.connect(printer)
    }

    func disconnect(_ printer: BluetoothPrinter) {
        manager.disconnect(printer)
    }

    func selectCharacteristic(_ key: String) {
        let parts = key.split(separator: "/", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return }
        if manager.useCharacteristic(parts[1], service: parts[0]) {
            selectedCharacteristic = key
        } else {
            append("Could not switch to \(key)", error: true)
        }
    }

    func rescan() {
        manager.stopScan()
        if let error = manager.startScan() {
            append("Scan failed: \(error)", error: true)
        } else {
            append("Scanning for printers…")
        }
    }

    /// Re-creates the manager with the service UUIDs typed in the sidebar.
    func applyServiceUUIDs() {
        let uuids = serviceUUIDs
            .split(whereSeparator: { $0 == "\n" || $0 == "," })
            .map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
            .filter { !$0.isEmpty }
        BluetoothPrinterManager.specifiedServices = Set(uuids)
        manager.disconnectAllPrinter()
        manager = BluetoothPrinterManager()
        bind()
        printers = []
        connected = nil
        append(uuids.isEmpty ? "Scanning for every connectable device" : "Scanning for services: \(uuids.joined(separator: ", "))")
    }

    // MARK: - Sending

    func send(_ data: Data, label: String) {
        guard !data.isEmpty else {
            append("Nothing to send", error: true)
            return
        }
        switch target {
        case .bluetooth:
            guard manager.canPrint else {
                append("No printer connected", error: true)
                return
            }
            isSending = true
            let started = Date()
            manager.write(data) { [weak self] error in
                self?.isSending = false
                let ms = Int(Date().timeIntervalSince(started) * 1000)
                if let error = error {
                    self?.append("\(label): failed after \(ms) ms – \(error)", error: true)
                } else {
                    self?.append("\(label): \(data.count) bytes handed to CoreBluetooth in \(ms) ms")
                }
            }
        case .network:
            isSending = true
            let started = Date()
            let printer = NetworkPrinter(host: networkHost, port: UInt16(clamping: networkPort))
            printer.write(data) { [weak self] error in
                self?.isSending = false
                let ms = Int(Date().timeIntervalSince(started) * 1000)
                if let error = error {
                    self?.append("\(label): \(self?.networkHost ?? ""):\(self?.networkPort ?? 0) failed after \(ms) ms – \(error)", error: true)
                } else {
                    self?.append("\(label): \(data.count) bytes sent to \(self?.networkHost ?? ""):\(self?.networkPort ?? 0) in \(ms) ms")
                }
            }
        case .devicePath:
            isSending = true
            let printer = SerialPrinter(path: devicePath, baudRate: baudRate)
            printer.write(data) { [weak self] error in
                self?.isSending = false
                if let error = error {
                    self?.append("\(label): \(error)", error: true)
                } else {
                    self?.append("\(label): \(data.count) bytes written to \(self?.devicePath ?? "")")
                }
            }
        case .file:
            let panel = NSSavePanel()
            panel.nameFieldStringValue = "receipt.bin"
            panel.canCreateDirectories = true
            guard panel.runModal() == .OK, let url = panel.url else { return }
            do {
                try data.write(to: url)
                append("\(label): saved \(data.count) bytes to \(url.path)")
            } catch {
                append("\(label): \(error.localizedDescription)", error: true)
            }
        }
    }


    // MARK: - Log

    func append(_ text: String, error: Bool = false) {
        DispatchQueue.main.async {
            self.log.append(LogEntry(text: text, isError: error))
            if self.log.count > 500 { self.log.removeFirst(self.log.count - 500) }
        }
    }

    func clearLog() {
        log.removeAll()
    }
}

/// One-shot commands that are useful while bringing up a printer.
enum QuickCommand: String, CaseIterable, Identifiable {
    case initialize, feed3, fullCut, partialCut, feedAndCut, cashDrawer, status, selfTest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .initialize: return "Initialize (ESC @)"
        case .feed3: return "Feed 3 lines"
        case .fullCut: return "Full cut (GS V 0)"
        case .partialCut: return "Partial cut (GS V 1)"
        case .feedAndCut: return "Feed & partial cut"
        case .cashDrawer: return "Open cash drawer"
        case .status: return "Query status (DLE EOT 1)"
        case .selfTest: return "Print test line"
        }
    }

    var bytes: [UInt8] {
        switch self {
        case .initialize: return Command.style(.initialize).assemblePrintableData(.🖨️58())
        case .feed3: return Command.page(.printAndFeed(lines: 3)).assemblePrintableData(.🖨️58())
        case .fullCut: return Command.page(.fullCut).assemblePrintableData(.🖨️58())
        case .partialCut: return Command.page(.partialCut).assemblePrintableData(.🖨️58())
        case .feedAndCut: return Command.page(.feedAndCut(partial: true, feed: 40)).assemblePrintableData(.🖨️58())
        case .cashDrawer: return Command.peripheral(.cashDrawer()).assemblePrintableData(.🖨️58())
        case .status: return Command.info(.realTimeStatus(1)).assemblePrintableData(.🖨️58())
        case .selfTest:
            let receipt = Receipt(.🖨️58(.ascii))
                <<~ .style(.initialize)
                <<~ .layout(.justification(.center))
                <<< "PrinterLab OK"
                <<< Dividing.default()
                <<~ .page(.printAndFeed(lines: 3))
            return receipt.data
        }
    }
}
