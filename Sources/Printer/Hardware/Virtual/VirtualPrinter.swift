//
//  VirtualPrinter.swift
//  Printer
//

import Foundation

/// Sends receipts to the web virtual printer (https://printer.baici.tech): open the page,
/// read the 6-character token it shows, and every `write` is rendered in that browser tab.
/// Handy while tuning a layout without a printer at hand.
///
/// ```swift
/// let printer = VirtualPrinter(token: "K7Q2MZ")
/// printer.write(receipt) { error in … }
/// ```
///
/// Protocol: `POST {baseURL}/api/v1/jobs/{token}` with the raw ESC/POS bytes as
/// `application/octet-stream`. `202` means the page received the job, `404` that
/// nobody is viewing that token.
public final class VirtualPrinter {
    public static let defaultBaseURL = URL(string: "https://printer.baici.tech")!

    public let token: String
    public let baseURL: URL
    /// Optional label shown next to the job in the browser.
    public var name: String?
    public var timeout: TimeInterval = 10

    private let session: URLSession

    public init(token: String, baseURL: URL = VirtualPrinter.defaultBaseURL, session: URLSession = .shared) {
        self.token = token.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        self.baseURL = baseURL
        self.session = session
    }

    public func write(_ receipt: Receipt, completeBlock: ((PError?) -> Void)? = nil) {
        write(receipt.bytes, completeBlock: completeBlock)
    }

    public func write(_ data: Data, completeBlock: ((PError?) -> Void)? = nil) {
        var request = URLRequest(url: jobURL)
        request.httpMethod = "POST"
        request.httpBody = data
        request.timeoutInterval = timeout
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        if let name {
            request.setValue(name, forHTTPHeaderField: "X-Printer-Name")
        }

        session.dataTask(with: request) { _, response, error in
            let result: PError?
            if let error {
                result = .writeFailed(error)
            } else if let http = response as? HTTPURLResponse {
                switch http.statusCode {
                case 200 ... 299: result = nil
                case 404: result = .deviceNotReady // nobody is viewing this token
                default: result = .writeFailed(VirtualPrinterError.httpStatus(http.statusCode))
                }
            } else {
                result = .writeFailed(VirtualPrinterError.noResponse)
            }
            DispatchQueue.main.async { completeBlock?(result) }
        }.resume()
    }

    public var jobURL: URL {
        baseURL.appendingPathComponent("api/v1/jobs/\(token)")
    }

    /// The page to open in a browser for this token.
    public var pageURL: URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "token", value: token)]
        return components.url ?? baseURL
    }

    public enum VirtualPrinterError: Error, LocalizedError {
        case httpStatus(Int)
        case noResponse

        public var errorDescription: String? {
            switch self {
            case let .httpStatus(code): return "virtual printer returned HTTP \(code)"
            case .noResponse: return "virtual printer did not respond"
            }
        }
    }
}
