//
//  NetworkPrinter.swift
//  Printer
//

import Foundation
import Network

/// Sends ESC/POS bytes to a printer over TCP. Nearly every Ethernet / Wi-Fi receipt
/// printer listens on port 9100 ("raw" / JetDirect) and prints whatever arrives.
///
/// ```swift
/// let printer = NetworkPrinter(host: "192.168.1.50")
/// printer.write(receipt) { error in … }
/// ```
///
/// A connection is opened per `write` call and closed once the bytes were sent,
/// which is what most printers expect; keep the object around to reuse the settings.
@available(iOS 12.0, macOS 10.14, *)
public final class NetworkPrinter {
    public let host: String
    public let port: UInt16
    /// Give up if the printer does not accept the connection within this time.
    public var connectTimeout: TimeInterval = 5

    private let queue = DispatchQueue(label: "com.kevin.gong.printer.network")

    public init(host: String, port: UInt16 = 9100) {
        self.host = host
        self.port = port
    }

    public func write(_ receipt: Receipt, completeBlock: ((PError?) -> Void)? = nil) {
        write(receipt.bytes, completeBlock: completeBlock)
    }

    public func write(_ data: Data, completeBlock: ((PError?) -> Void)? = nil) {
        guard let port = NWEndpoint.Port(rawValue: port) else {
            completeBlock?(.deviceNotReady)
            return
        }

        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        let connection = NWConnection(host: NWEndpoint.Host(host), port: port, using: params)

        var finished = false
        let finish: (PError?) -> Void = { error in
            guard !finished else { return }
            finished = true
            connection.cancel()
            DispatchQueue.main.async { completeBlock?(error) }
        }

        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                connection.send(content: data, completion: .contentProcessed { error in
                    if let error {
                        finish(.writeFailed(error))
                    } else {
                        finish(nil)
                    }
                })
            case let .failed(error), let .waiting(error):
                finish(.writeFailed(error))
            case .cancelled:
                finish(.disconnected)
            default:
                break
            }
        }

        queue.asyncAfter(deadline: .now() + connectTimeout) {
            finish(.connectFailed)
        }
        connection.start(queue: queue)
    }
}
