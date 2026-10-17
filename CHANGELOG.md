# Changelog

## 5.1.0 — unreleased

### Added
- `VirtualPrinter(token:)`: sends receipts to the web virtual printer (https://printer.baici.tech), which renders them in the browser — tune layouts without hardware. PrinterLab gained a matching output target.

## 5.0.0 — 2026-10-17

### Breaking
- CocoaPods support removed; use Swift Package Manager. `Printer.podspec` and the fastlane release lane are gone.
- Minimum deployment target is iOS 12 (also builds for macOS 10.15 without the UIKit picker).
- `Command.CharacterCodePage` now uses the Epson `ESC t` values (`.pc437 = 0`, `.wpc1252 = 16`, `.wpc1256 = 50`, …). The old `.ascii` / `.cp437` / `.cp808` names are deprecated aliases; `.georgian` was removed. The command byte itself was wrong (`27 166`) and is now `27 116`.
- `.page(.fullCut)` / `.page(.partialCut)` emit `GS V 0` / `GS V 1`. The old `ESC i` / `ESC m` bytes are available as `.page(.legacyCut(partial:))`.
- `PError` gained `.disconnected`, `.notSupported`, `.writeFailed(Error)`.
- `QRCode(content:width:…)` is deprecated; `width` was never a valid parameter. Use `moduleSize:` (1…16).

### Fixed
- Images: the gray formula used `&` instead of `*` for the green channel, capping gray at 106 so the default threshold produced an all-white image; dark pixels were also mapped to white (inverted). Pixel access assumed 4 bytes per pixel and crashed on RGB / grayscale / padded images ("Index out of range", #15 #23 #31 #35 #52 #55 #57 #60 #67). Images are now re-rendered through CoreGraphics and work with any `CGImage`.
- Images wider than the paper are scaled to fit (#52) and long images are sent in bands (#68).
- QR codes: model / module-size / print commands had wrong function codes and lengths, so many printers printed nothing (#15 #36 #63 #67). Thanks @joaocolaco (#79).
- Text that cannot be encoded is converted lossily instead of being dropped silently (#39 #66 #78).
- Bluetooth writes are chunked (20 bytes by default, `writeChunkSize`) and paced with `canSendWriteWithoutResponse`; previously the whole receipt was passed to one `writeValue` call and anything beyond what the module accepts was lost (#16 #52 #57 #68). Verified on a Gprinter GP-58: packets of 182 bytes (the negotiated MTU) are silently truncated and print as garbage, 20-byte packets print correctly. Set `writeChunkSize = 0` to use the MTU on printers that cope.
- A writable characteristic is picked by its properties, so printers with unknown characteristic UUIDs work. Default service list covers Gprinter / Xprinter, ISSC (GoojPRT, PT-210), `18F0`, `FFE0`, `FF00` (#12 #33 #80).
- Printers that expose several serial-port services (e.g. Gprinter: `18F0` + ISSC + `E7810A71`) picked whichever service answered first, which on a GP-58 is the dead `18F0/2AF1` characteristic — nothing printed although the connection succeeded. Discovery now waits for every matching service and picks by `BluetoothPrinterManager.characteristicPriority`; `writableCharacteristics` / `useCharacteristic(_:service:)` let an app switch manually and `diagnostics` traces discovery, the chosen characteristic, MTU and chunking.
- `BluetoothPeripheralDelegate` no longer marks a printer writable when no characteristic was found; `errorReport` receives `.notSupported` instead.
- Race in the discovered-peripheral dictionary; connected peripherals adopted at start-up are now listed.
- `KVItem` width now counts CJK characters as two cells using Unicode ranges instead of a single range.

### Added
- `NetworkPrinter` (TCP 9100, iOS + macOS) for Ethernet / Wi-Fi printers (#70 #72) and `SerialPrinter` (macOS, `/dev/cu.*`) for USB-serial printers.
- `Tools/PrinterLab`: macOS test app covering every feature over Bluetooth LE, TCP or serial, with hex dump and transfer log.
- `ImageItem(binarization: .dither)` Floyd–Steinberg dithering; `ImageItem(data:)` and `ImageItem(base64:)` (#71 #81).
- `Barcode` (`GS k`): UPC-A/E, EAN-13/8, CODE39, ITF, CODABAR, CODE93, CODE128 (#60).
- `Command.peripheral(.cashDrawer(...))` (#78), `.style(.characterSize(width:height:))`, `.style(.selectInternationalCharacterSet(_:))`, `.layout(.leftMargin(_:))`, `.layout(.printAreaWidth(_:))`, `.page(.feedAndCut(partial:feed:))`, `.page(.printAndFeedPaper(dots:))`, `.info(.realTimeStatus(_:))`, `Command.raw([UInt8])`.
- `Text` item (no trailing line feed), `PrinterProfile.🖨️80`, `.paper58` / `.paper80`, `PrinterProfile.charactersPerLine`, `Receipt.bytes`.
- `BluetoothPrinterManager.write(_ receipt:)`, `writeChunkSize`, `interChunkDelay`.
- `String.ArabicEncoding.windowsArabic`.
- `DummyPrinter.history` / `onWrite` / `logsToConsole`.
- Unit tests for every item and command; GitHub Actions CI (`swift test` on macOS + iOS Simulator build).
- README with encoding / code-page guide, printer compatibility table, SwiftUI example and troubleshooting (#66 #76 #78).

### Changed
- Example app uses the local package instead of CocoaPods and demonstrates dithered images, QR, barcode and cut.

## 4.0.1 and earlier
See git history.
