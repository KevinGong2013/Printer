# Printer

[![CI](https://github.com/KevinGong2013/Printer/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/KevinGong2013/Printer/actions/workflows/ci.yml)
[![Version](https://img.shields.io/github/v/tag/KevinGong2013/Printer?sort=semver&label=version)](https://github.com/KevinGong2013/Printer/tags)
[![Swift Package Manager](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)
[![Platforms](https://img.shields.io/badge/platforms-iOS%2012%2B%20%7C%20macOS%2010.15%2B-blue.svg)](Package.swift)
[![Swift](https://img.shields.io/badge/Swift-5.7%2B-orange.svg)](https://swift.org)
[![License](https://img.shields.io/github/license/KevinGong2013/Printer)](LICENSE)

Swift framework for ESC/POS thermal receipt printers over **Bluetooth LE**,
**TCP/IP** and (on macOS) **serial / USB-serial**.

Build a receipt with a tiny DSL, get the raw ESC/POS bytes, and send them to any
58 mm / 80 mm printer that speaks ESC/POS (Gprinter, Xprinter, Munbyn, Rongta,
GoojPRT, Epson TM-m/TM-T with BLE module, …).

```swift
let receipt = Receipt(.🖨️58(.utf8))
    <<~ .style(.initialize)
    <<~ .layout(.justification(.center))
    <<~ .style(.characterSize(width: 2, height: 2))
    <<< "My Shop"
    <<~ .style(.characterSize(width: 1, height: 1))
    <<< Dividing.default()
    <<~ .layout(.justification(.left))
    <<< KVItem("Coffee", "3.50")
    <<< KVItem("Total", "3.50")
    <<< ImageItem(logo.cgImage!, binarization: .dither)
    <<< QRCode(content: "https://example.com")
    <<< Barcode("ORDER-42")
    <<~ .page(.printAndFeed(lines: 3))
    <<~ .page(.feedAndCut(partial: true, feed: 0))

printerManager.write(receipt) { error in … }
```

## No printer at hand? Try the virtual printer

Open <https://printer.baici.tech> in any browser. The page shows a 6-character token;
send receipts to it and watch them render live, with the hex dump next to the image.

```swift
let printer = VirtualPrinter(token: "K7Q2MZ")   // the token on the page
printer.write(receipt) { error in … }
```

The [Example app](Example) has a **Virtual Printer** button that does exactly this, and
the same token works from the [Android library](https://github.com/KevinGong2013/Printer-Android)
and from `curl`. Details in [Virtual printer in the browser](#virtual-printer-in-the-browser).

## Requirements

- iOS 12+ (the receipt builder also compiles for macOS 10.15+)
- Swift 5.7+ / Xcode 14+

## Installation

Swift Package Manager only (CocoaPods support was dropped in 5.0).

```swift
dependencies: [
    .package(url: "https://github.com/KevinGong2013/Printer.git", from: "5.0.0")
]
```

or in Xcode: *File ▸ Add Package Dependencies…* and paste the repository URL.

Add `NSBluetoothAlwaysUsageDescription` to your app's `Info.plist`, otherwise iOS
terminates the app the first time it touches Bluetooth.

## Building a receipt

`Receipt` is a list of `ReceiptItem`s rendered against a `PrinterProfile`
(paper width, character width, text encoding).

| Profile | Dots | Use for |
|---|---|---|
| `.🖨️58(encoding)` / `.paper58(encoding)` | 384 | 58 mm paper |
| `.🖨️80(encoding)` / `.paper80(encoding)` | 576 | 80 mm paper |
| `PrinterProfile(maxWidthDensity:fontDensity:encoding:)` | any | custom |

Two operators append items:

- `<<<` appends any `ReceiptItem` (`String`, `Text`, `KVItem`, `Dividing`, `ImageItem`, `QRCode`, `Barcode`, …)
- `<<~` appends a raw `Command` (style, layout, cursor, page, peripheral, or `.raw([UInt8])`)

### Text

| Item | Output |
|---|---|
| `"Hello"` | the line, followed by a line feed |
| `Text("Hello")` | the text without a line feed (combine several on one line) |
| `KVItem("Total", "5.50")` | key left-aligned, value right-aligned, full width |
| `Dividing.default()` | a line of `-` across the paper |

Styles are plain commands: `.style(.emphasis(enable: true))`,
`.style(.characterSize(width: 2, height: 2))`, `.style(.underlineMode(.enable1dot))`,
`.layout(.justification(.center))`, `.layout(.lineSpace(.raw(40)))` …

### Images

```swift
ImageItem(cgImage)                                  // threshold 128
ImageItem(cgImage, grayThreshold: 160)              // lighter images print more black
ImageItem(cgImage, binarization: .dither)           // Floyd–Steinberg, best for photos / logos
ImageItem(cgImage, mode: .doubleWH)                 // printer-side 2× magnification
ImageItem(data: pngData)                            // PNG / JPEG data
ImageItem(base64: "data:image/png;base64,....")     // base64 string
```

- Any `CGImage` works (RGB, RGBA, grayscale, indexed, alpha or not). Transparent
  pixels print white.
- Images wider than the paper are scaled down automatically. Pass
  `scaling: .none` to keep the native size.
- Long images are sent in bands of 64 rows (`rowsPerBand:`) so the printer starts
  immediately and never overflows its buffer. If you still see white gaps across
  images, raise `printerManager.interChunkDelay` (e.g. `0.01`) or lower
  `printerManager.writeChunkSize` (e.g. `100`).

### QR code and barcodes

```swift
QRCode(content: "https://example.com", moduleSize: 6, recovery: .m)   // moduleSize 1…16 dots
QRCode(content: "中文", encoding: .utf8)                                // override the profile encoding
Barcode("4901234567894", symbology: .ean13, height: 80, text: .below)
Barcode("ORDER-42")                                                     // CODE128, code set B
```

Both use the printer's built-in symbol generator. Nearly every ESC/POS printer
supports QR (`GS ( k`) and CODE128 / EAN13; very old or label-only models may not.

### Cutting, feeding, cash drawer

```swift
<<~ .page(.printAndFeed(lines: 3))
<<~ .page(.fullCut)                       // GS V 0
<<~ .page(.feedAndCut(partial: true, feed: 30))
<<~ .page(.legacyCut(partial: false))     // ESC i, for printers without GS V
<<~ .peripheral(.cashDrawer())            // ESC p 0 50 250
```

### Encodings, umlauts, €, Arabic, Chinese

Thermal printers have no Unicode. You pick a **code page** on the printer and
encode your strings in the matching **String.Encoding**; both must agree.

| Language | Profile encoding | Command |
|---|---|---|
| English only | `.ascii` | – |
| Western Europe (ä ö ü é €) | `.windowsCP1252` | `.style(.selectCharacterCodePage(.wpc1252))` |
| Chinese (Gprinter / Xprinter …) | `String.GBEncoding.GB_18030_2000` | usually none needed |
| Arabic | `String.ArabicEncoding.windowsArabic` | `.style(.selectCharacterCodePage(.wpc1256))` |
| Cyrillic | `.windowsCP1251` | `.style(.selectCharacterCodePage(.wpc1251))` |
| Greek | `.windowsCP1253` | `.style(.selectCharacterCodePage(.wpc1253))` |

```swift
let receipt = Receipt(.🖨️58(.windowsCP1252))
    <<~ .style(.initialize)
    <<~ .style(.selectCharacterCodePage(.wpc1252))
    <<< "Größe: 5 €"
```

Characters the chosen encoding cannot represent are replaced (usually with `?`)
instead of dropping the whole line. Some printers ship with a different code-page
table than Epson's; check the self-test page that prints when you hold the feed
button while powering on.

## Printing over Bluetooth

```swift
let printerManager = BluetoothPrinterManager()

printerManager.updateHandler = { /* printerManager.nearbyPrinters changed */ }
printerManager.errorReport = { error in print(error) }

// scanning starts automatically once Bluetooth is powered on
printerManager.connect(printerManager.nearbyPrinters[0])

if printerManager.canPrint {
    printerManager.write(receipt) { error in
        // nil when every byte was handed to CoreBluetooth
    }
}
```

`write` splits the data into 20-byte packets (`writeChunkSize`) and paces them with
`canSendWriteWithoutResponse`, so receipts of any length (images included) arrive
intact. 20 bytes is what every module handles; printers that accept full-MTU packets
print images several times faster with `writeChunkSize = 0`, so try that once the
basics work. `diagnostics` prints the discovered services, the chosen characteristic,
MTU and packet count when you need to see what is going on. The manager remembers the last printer and reconnects to it on the next
launch when it is in range.

`BluetoothPrinterSelectTableViewController` is a ready-made UIKit picker; see the
Example app.

### Which printers are found?

The manager scans for the GATT services used by common BLE printer modules:

| Service | Write characteristic | Typical printers |
|---|---|---|
| `E7810A71-73AE-499D-8C15-FAA9AEF0C3F2` | `BEF8D6C9-9C21-4C9E-B632-BD58C1009F9F` | Gprinter, Xprinter, Munbyn |
| `49535343-FE7D-4AE5-8FA9-9FAFD205E455` | `49535343-8841-43F4-A8D4-ECBE34729BB3` | Microchip ISSC: GoojPRT PT-210, many 58 mm minis |
| `18F0` | `2AF1` | Epson, generic |
| `FFE0` / `FF00` | `FFE1` / `FF02` | HM-10 / Telink UART bridges |

Within a matched service the first characteristic that accepts writes is used, so
unknown characteristic UUIDs are fine. If your printer uses another service UUID,
set it **before** creating the manager:

```swift
BluetoothPrinterManager.specifiedServices = ["0000AE30-0000-1000-8000-00805F9B34FB"]
let printerManager = BluetoothPrinterManager()
```

An empty set scans for every connectable device. Use a BLE scanner app
(nRF Connect, LightBlue) to find your printer's service UUID.

Printers that only offer **classic Bluetooth (SPP)** cannot be used from iOS;
check the box for "BLE" or "iOS support" before buying.

## Virtual printer in the browser

Open <https://printer.baici.tech>, read the 6-character token on the page, and send
receipts to it like to any other printer. Every job is rendered as a receipt image
in that tab, with the hex dump next to it — no hardware needed while tuning a layout.

```swift
let printer = VirtualPrinter(token: "K7Q2MZ")   // the token shown on the page
printer.write(receipt) { error in … }           // .deviceNotReady = nobody is viewing that token
```

The same token works from the Android library and from `curl`
(`POST https://printer.baici.tech/api/v1/jobs/K7Q2MZ` with the raw bytes).

## Network and wired printers

```swift
// Ethernet / Wi-Fi printers listen on TCP 9100 and print whatever arrives.
let lan = NetworkPrinter(host: "192.168.1.50")          // iOS + macOS
lan.write(receipt) { error in … }

// USB-serial printers on a Mac (CH340 / FTDI adapters show up as /dev/cu.*).
let usb = SerialPrinter(path: "/dev/cu.usbserial-1430", baudRate: 9600)   // macOS only
usb.write(receipt) { error in … }
```

iOS exposes no generic USB API, so wired printers are macOS only. USB printers
that enumerate as a *USB Printer Class* device (no `/dev/cu.*` node) are not
supported yet; use their Bluetooth or network interface instead.

## Testing with PrinterLab (macOS)

[Tools/PrinterLab](Tools/PrinterLab) is a macOS app that drives every feature of
this package against a real printer over Bluetooth LE, TCP or a serial device:
scan / connect, text styles, code pages, images (threshold or dither), QR,
barcodes, cuts, cash drawer, raw commands, with a live hex dump and a transfer
log. Generate the project with `xcodegen generate` in that folder and run it.

## SwiftUI

```swift
final class PrinterModel: ObservableObject {
    let manager = BluetoothPrinterManager()
    @Published var printers: [BluetoothPrinter] = []

    init() {
        manager.updateHandler = { [weak self] in
            self?.printers = self?.manager.nearbyPrinters ?? []
        }
    }
}

struct PrinterList: View {
    @StateObject private var model = PrinterModel()

    var body: some View {
        List(model.printers, id: \.identifier) { printer in
            Button(printer.name ?? "Unknown") { model.manager.connect(printer) }
        }
    }
}
```

## Without hardware

`DummyPrinter` records every payload (`history`, `onWrite`) and logs it as base64,
handy in unit tests and when asking for help in an issue.

## Troubleshooting

- **Nothing prints, no error** – check `canPrint`; `errorReport` receives
  `.notSupported` when the printer has no writable characteristic and
  `.disconnected` when it dropped mid-job.
- **Image prints blank / inverted / cut off** – update to 5.0; earlier versions
  had a broken gray conversion and sent the whole image in one write.
- **Connected, but nothing prints, or only garbage** – packets are too large for
  the module. Keep `writeChunkSize` at 20 (the default); if you raised it, lower it.
  Also power-cycle the printer after your app was killed mid-connection: some
  modules refuse a new connection until the old link times out.
- **White horizontal lines in images** – the printer is being fed faster than it
  prints. Set `interChunkDelay = 0.01`.
- **`¥` prints as a Chinese character, or the last digit of a `KVItem` price wraps
  to the next line** (Gprinter / Xprinter with `GB_18030_2000`) – update the library.
  CoreFoundation encodes `¥` (U+00A5) as the 4-byte GB18030 sequence `81 30 84 36`,
  which GBK-only firmware draws as an unrelated ideograph; the library now sends
  the full-width `￥` (`A3 A4`) on GB profiles and counts every multi-byte character
  as two cells when laying out `KVItem`.
- **Garbage instead of accented letters** – profile encoding and
  `selectCharacterCodePage` do not match; see the encoding table above.
- **"Index out of range" when printing an image** – fixed in 5.0.
- **Cut command does nothing** – your printer has no cutter; the command is ignored.

## License

Apache License 2.0. See [LICENSE](LICENSE).
