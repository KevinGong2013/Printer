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
                Button("Rescan Bluetooth") { session.rescan() }
                    .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}
