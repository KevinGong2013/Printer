//
//  SerialPrinter.swift
//  Printer
//

#if os(macOS)
    import Darwin
    import Foundation

    /// Writes ESC/POS bytes to a character device on macOS: a USB-serial adapter
    /// (`/dev/cu.usbserial-*`, `/dev/cu.wchusbserial*`) or any other writable device file.
    ///
    /// Many desk-top thermal printers that show up as a CH340 / FTDI serial port on the
    /// Mac work with this. iOS has no equivalent API, so this type is macOS only.
    public final class SerialPrinter {
        public let path: String
        /// Baud rate applied when the path is a TTY. Ignored for other files.
        public var baudRate: Int

        private let queue = DispatchQueue(label: "com.kevin.gong.printer.serial")

        public init(path: String, baudRate: Int = 9600) {
            self.path = path
            self.baudRate = baudRate
        }

        public func write(_ receipt: Receipt, completeBlock: ((PError?) -> Void)? = nil) {
            write(receipt.bytes, completeBlock: completeBlock)
        }

        public func write(_ data: Data, completeBlock: ((PError?) -> Void)? = nil) {
            queue.async {
                let result: PError?
                do {
                    try self.writeSync(data)
                    result = nil
                } catch {
                    result = .writeFailed(error)
                }
                DispatchQueue.main.async { completeBlock?(result) }
            }
        }

        /// Blocking variant.
        public func writeSync(_ data: Data) throws {
            let fd = open(path, O_WRONLY | O_APPEND | O_NOCTTY | O_NONBLOCK)
            guard fd >= 0 else {
                throw SerialError.open(path, errno)
            }
            defer { close(fd) }
            _ = fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) & ~O_NONBLOCK)

            var tio = termios()
            if tcgetattr(fd, &tio) == 0 {
                cfmakeraw(&tio)
                cfsetspeed(&tio, speed_t(baudRate))
                tio.c_cflag |= tcflag_t(CLOCAL | CREAD)
                tcsetattr(fd, TCSANOW, &tio)
            }

            var failure: Int32 = 0
            data.withUnsafeBytes { buffer in
                guard let base = buffer.baseAddress else { return }
                var offset = 0
                while offset < buffer.count {
                    let n = Darwin.write(fd, base + offset, buffer.count - offset)
                    if n < 0 {
                        failure = errno
                        return
                    }
                    offset += n
                }
            }
            if failure != 0 {
                throw SerialError.write(path, failure)
            }
            tcdrain(fd)
        }

        public enum SerialError: Error, LocalizedError {
            case open(String, Int32)
            case write(String, Int32)

            public var errorDescription: String? {
                switch self {
                case let .open(path, code): return "open \(path): \(String(cString: strerror(code)))"
                case let .write(path, code): return "write \(path): \(String(cString: strerror(code)))"
                }
            }
        }
    }
#endif
