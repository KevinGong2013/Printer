import Printer
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var session: PrinterSession
    @EnvironmentObject private var draft: ReceiptDraft

    var body: some View {
        NavigationSplitView {
            PrintersSidebar()
                .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 380)
        } detail: {
            HSplitView {
                ReceiptForm()
                    .frame(minWidth: 420, idealWidth: 520)
                PreviewPane()
                    .frame(minWidth: 380, idealWidth: 460)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    ForEach(QuickCommand.allCases) { command in
                        Button(command.title) { session.send(Data(command.bytes), label: command.title) }
                    }
                } label: {
                    Label("Quick Commands", systemImage: "bolt")
                }

                Button {
                    session.send(draft.bytes, label: "receipt")
                } label: {
                    Label("Send Receipt", systemImage: "printer")
                }
                .keyboardShortcut("p", modifiers: .command)
                .disabled(session.isSending)
            }
        }
    }
}

struct PrintersSidebar: View {
    @EnvironmentObject private var session: PrinterSession
    @State private var showServices = false

    var body: some View {
        List {
            Section("Output") {
                Picker("Target", selection: $session.target) {
                    ForEach(PrinterSession.Target.allCases) { Text($0.rawValue).tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.radioGroup)

                if session.target == .network {
                    HStack {
                        TextField("Host / IP", text: $session.networkHost)
                            .textFieldStyle(.roundedBorder)
                        TextField("Port", value: $session.networkPort, format: .number.grouping(.never))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 70)
                    }
                    Text("Raw TCP, the port most Ethernet / Wi-Fi ESC/POS printers listen on.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                if session.target == .devicePath {
                    TextField("Device path", text: $session.devicePath)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Text("Baud")
                        TextField("", value: $session.baudRate, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 90)
                        Spacer()
                        Button("Pick…") { pickDevice() }
                    }
                    Text("Writes the raw bytes to a serial port (/dev/cu.*) or any writable device file.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            if session.target == .bluetooth {
                Section {
                    if session.printers.isEmpty {
                        Text("No printers found yet.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(session.printers, id: \.identifier) { printer in
                        PrinterRow(printer: printer)
                    }
                } header: {
                    HStack {
                        Text("Bluetooth printers")
                        Spacer()
                        Button {
                            session.rescan()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.borderless)
                        .help("Rescan")
                    }
                }

                if !session.characteristics.isEmpty {
                    Section("Write characteristic") {
                        Picker("", selection: Binding(
                            get: { session.selectedCharacteristic },
                            set: { session.selectCharacteristic($0) }
                        )) {
                            ForEach(session.characteristics, id: \.characteristic) { item in
                                Text("\(short(item.service)) / \(short(item.characteristic))")
                                    .tag("\(item.service)/\(item.characteristic)")
                            }
                        }
                        .labelsHidden()
                        Text("If nothing prints, try another one.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Section("Transfer") {
                    LabeledContent("Chunk size") {
                        TextField("auto", value: $session.chunkSize, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 70)
                    }
                    LabeledContent("Delay (ms)") {
                        TextField("0", value: $session.interChunkDelayMs, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 70)
                    }
                    Text("0 = negotiated MTU, no delay. Lower chunk / add delay if images show white lines.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section {
                    DisclosureGroup("Service UUIDs", isExpanded: $showServices) {
                        TextEditor(text: $session.serviceUUIDs)
                            .font(.system(.caption, design: .monospaced))
                            .frame(height: 90)
                        Button("Apply & rescan") { session.applyServiceUUIDs() }
                        Text("One per line. Empty = every connectable device.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func short(_ uuid: String) -> String {
        uuid.count > 8 ? String(uuid.prefix(8)) + "…" : uuid
    }

    private func pickDevice() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/dev")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.treatsFilePackagesAsDirectories = true
        panel.showsHiddenFiles = true
        if panel.runModal() == .OK, let url = panel.url {
            session.devicePath = url.path
        }
    }
}

private struct PrinterRow: View {
    @EnvironmentObject private var session: PrinterSession
    let printer: BluetoothPrinter

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(printer.name ?? "Unknown")
                Text(printer.identifier.uuidString.prefix(8) + "…")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            switch printer.state {
            case .connected:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Button("Disconnect") { session.disconnect(printer) }
                    .buttonStyle(.borderless)
            case .connecting, .disconnecting:
                ProgressView().controlSize(.small)
            case .disconnected:
                Button("Connect") { session.connect(printer) }
                    .buttonStyle(.borderless)
            }
        }
    }
}
