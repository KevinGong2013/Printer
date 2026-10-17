import SwiftUI

@main
struct PrinterLabApp: App {
    @StateObject private var session = PrinterSession()
    @StateObject private var draft = ReceiptDraft()

    var body: some Scene {
        WindowGroup("PrinterLab") {
            ContentView()
                .environmentObject(session)
                .environmentObject(draft)
                .frame(minWidth: 1100, minHeight: 700)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Printer") {
                Button("Send Receipt") { session.send(draft.bytes, label: "receipt") }
                    .keyboardShortcut("p", modifiers: .command)
                Divider()
                ForEach(QuickCommand.allCases) { command in
                    Button(command.title) { session.send(Data(command.bytes), label: command.title) }
                }
                Divider()
                Menu("Write characteristic") {
                    ForEach(session.characteristics, id: \.characteristic) { item in
                        Button((session.selectedCharacteristic == "\(item.service)/\(item.characteristic)" ? "✓ " : "") + "\(item.service) / \(item.characteristic)") {
                            session.selectCharacteristic("\(item.service)/\(item.characteristic)")
                        }
                    }
                }
                Menu("Chunk size") {
                    ForEach([0, 20, 100, 182], id: \.self) { size in
                        Button((session.chunkSize == size ? "✓ " : "") + (size == 0 ? "Auto (MTU)" : "\(size) bytes")) { session.chunkSize = size }
                    }
                }
                Toggle("Write with response", isOn: $session.writeWithResponse)
                Divider()
                Button("Rescan Bluetooth") { session.rescan() }
                    .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}
