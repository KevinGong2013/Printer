import Printer
import SwiftUI

struct PreviewPane: View {
    @EnvironmentObject private var session: PrinterSession
    @EnvironmentObject private var draft: ReceiptDraft

    var body: some View {
        let data = draft.bytes
        VSplitView {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("ESC/POS bytes")
                        .font(.headline)
                    Text("\(data.count) bytes")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Copy hex") { copy(data.map { String(format: "%02X", $0) }.joined(separator: " ")) }
                    Button("Copy base64") { copy(data.base64EncodedString()) }
                        .help("Paste this into a GitHub issue")
                }
                ScrollView {
                    Text(data.hexDump())
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color(nsColor: .textBackgroundColor))
                .border(.separator)
            }
            .padding()
            .frame(minHeight: 200)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Log").font(.headline)
                    if session.isSending { ProgressView().controlSize(.small) }
                    Spacer()
                    if let printer = session.connected {
                        Label(printer.name ?? "connected", systemImage: "dot.radiowaves.left.and.right")
                            .foregroundStyle(.green)
                    }
                    Button("Clear") { session.clearLog() }
                }
                ScrollViewReader { proxy in
                    List(session.log) { entry in
                        HStack(alignment: .top) {
                            Text(entry.date, format: .dateTime.hour().minute().second())
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                            Text(entry.text)
                                .foregroundStyle(entry.isError ? .red : .primary)
                                .textSelection(.enabled)
                        }
                        .font(.system(size: 12))
                        .id(entry.id)
                    }
                    .onChange(of: session.log.count) { _ in
                        if let last = session.log.last { proxy.scrollTo(last.id) }
                    }
                }
                .border(.separator)
            }
            .padding()
            .frame(minHeight: 150)
        }
    }

    private func copy(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
}
