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

final class VirtualPrinterTests: XCTestCase {
    /// Minimal HTTP server on a random port: records the request and answers `status`.
    private func serve(status: Int, onRequest: @escaping (String, Data) -> Void) throws -> UInt16 {
        let listener = try NWListener(using: .tcp, on: .any)
        listener.newConnectionHandler = { connection in
            connection.start(queue: .global())
            var buffer = Data()
            func read() {
                connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, _, _ in
                    if let data { buffer.append(data) }
                    guard let headerEnd = buffer.range(of: Data("\r\n\r\n".utf8)) else { return read() }
                    let head = String(decoding: buffer[..<headerEnd.lowerBound], as: UTF8.self)
                    let length = head.split(separator: "\r\n")
                        .first { $0.lowercased().hasPrefix("content-length:") }
                        .flatMap { Int($0.split(separator: ":")[1].trimmingCharacters(in: .whitespaces)) } ?? 0
                    let body = buffer[headerEnd.upperBound...]
                    guard body.count >= length else { return read() }
                    onRequest(head, Data(body.prefix(length)))
                    let reply = "HTTP/1.1 \(status) X\r\nContent-Length: 2\r\nConnection: close\r\n\r\n{}"
                    connection.send(content: Data(reply.utf8), completion: .contentProcessed { _ in connection.cancel() })
                }
            }
            read()
        }
        let ready = expectation(description: "ready")
        listener.stateUpdateHandler = { if case .ready = $0 { ready.fulfill() } }
        listener.start(queue: .global())
        wait(for: [ready], timeout: 5)
        addTeardownBlock { listener.cancel() }
        return try XCTUnwrap(listener.port?.rawValue)
    }

    func testPostsRawBytesToTokenURL() throws {
        var head = "", body = Data()
        let got = expectation(description: "request")
        let port = try serve(status: 202) { h, b in head = h; body = b; got.fulfill() }

        let printer = VirtualPrinter(token: " k7q2mz\n", baseURL: URL(string: "http://127.0.0.1:\(port)")!)
        printer.name = "unit test"
        let done = expectation(description: "done")
        var result: PError? = .deviceNotReady
        printer.write(Data([27, 64, 0x41, 10])) { result = $0; done.fulfill() }
        wait(for: [got, done], timeout: 5)

        XCTAssertNil(result)
        XCTAssertTrue(head.hasPrefix("POST /api/v1/jobs/K7Q2MZ HTTP/1.1"), head)
        XCTAssertTrue(head.lowercased().contains("content-type: application/octet-stream"))
        XCTAssertTrue(head.contains("X-Printer-Name: unit test"))
        XCTAssertEqual(body, Data([27, 64, 0x41, 10]))
        XCTAssertEqual(printer.pageURL.absoluteString, "http://127.0.0.1:\(port)?token=K7Q2MZ")
    }

    func testUnknownTokenIsDeviceNotReady() throws {
        let port = try serve(status: 404) { _, _ in }
        let printer = VirtualPrinter(token: "ABCDEF", baseURL: URL(string: "http://127.0.0.1:\(port)")!)
        let done = expectation(description: "done")
        var result: PError?
        printer.write(Data([1])) { result = $0; done.fulfill() }
        wait(for: [done], timeout: 5)
        guard case .deviceNotReady? = result else { return XCTFail("expected deviceNotReady, got \(String(describing: result))") }
    }

    func testServerErrorIsWriteFailed() throws {
        let port = try serve(status: 500) { _, _ in }
        let printer = VirtualPrinter(token: "ABCDEF", baseURL: URL(string: "http://127.0.0.1:\(port)")!)
        let done = expectation(description: "done")
        var result: PError?
        printer.write(Data([1])) { result = $0; done.fulfill() }
        wait(for: [done], timeout: 5)
        guard case .writeFailed? = result else { return XCTFail("expected writeFailed, got \(String(describing: result))") }
    }
}
