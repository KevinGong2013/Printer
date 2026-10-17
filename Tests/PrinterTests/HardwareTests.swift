//
//  HardwareTests.swift
//  PrinterTests
//

import Foundation
import Network
@testable import Printer
import XCTest

final class NetworkPrinterTests: XCTestCase {
    func testSendsBytesOverTCP() throws {
        let received = expectation(description: "bytes received")
        let listener = try NWListener(using: .tcp, on: .any)
        var collected = Data()
        listener.newConnectionHandler = { connection in
            connection.start(queue: .global())
            func read() {
                connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, _ in
                    if let data { collected.append(data) }
                    if collected.count >= 5 || isComplete { received.fulfill() } else { read() }
                }
            }
            read()
        }
        let ready = expectation(description: "listener ready")
        listener.stateUpdateHandler = { if case .ready = $0 { ready.fulfill() } }
        listener.start(queue: .global())
        wait(for: [ready], timeout: 5)

        let port = try XCTUnwrap(listener.port?.rawValue)
        let printer = NetworkPrinter(host: "127.0.0.1", port: port)
        let done = expectation(description: "write completed")
        var result: PError? = .deviceNotReady
        printer.write(Data([27, 64, 0x41, 0x42, 10])) { error in
            result = error
            done.fulfill()
        }
        wait(for: [done, received], timeout: 5)
        listener.cancel()

        XCTAssertNil(result)
        XCTAssertEqual(collected, Data([27, 64, 0x41, 0x42, 10]))
    }

    func testConnectionRefusedReportsError() {
        let printer = NetworkPrinter(host: "127.0.0.1", port: 1) // nothing listens on port 1
        printer.connectTimeout = 3
        let done = expectation(description: "completed")
        var result: PError?
        printer.write(Data([1])) { error in
            result = error
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        XCTAssertNotNil(result)
    }
}

#if os(macOS)
    final class SerialPrinterTests: XCTestCase {
        func testWritesToDeviceFile() throws {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("printer-\(UUID().uuidString).bin")
            FileManager.default.createFile(atPath: url.path, contents: nil)
            defer { try? FileManager.default.removeItem(at: url) }

            let printer = SerialPrinter(path: url.path)
            let receipt = Receipt(.🖨️58()) <<< "ok"
            try printer.writeSync(receipt.bytes)
            XCTAssertEqual(try Data(contentsOf: url), Data([0x6F, 0x6B, 10]))

            let done = expectation(description: "async write")
            printer.write(Data([1, 2])) { error in
                XCTAssertNil(error)
                done.fulfill()
            }
            wait(for: [done], timeout: 2)
            XCTAssertEqual(try Data(contentsOf: url), Data([0x6F, 0x6B, 10, 1, 2]))
        }

        func testMissingDeviceFails() {
            let printer = SerialPrinter(path: "/dev/cu.does-not-exist")
            XCTAssertThrowsError(try printer.writeSync(Data([1])))
        }
    }
#endif
