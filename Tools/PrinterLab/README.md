# PrinterLab

macOS app for exercising every feature of the `Printer` package against a real
printer: Bluetooth LE scanning / connecting, text styles, code pages, key/value
lines, images (threshold or dither, scaling, banding), QR codes, barcodes, raw
commands, feeding, cutting and the cash drawer. The right pane shows the exact
ESC/POS bytes and a log of every transfer.

Output targets:

- **Bluetooth LE** – uses `BluetoothPrinterManager` exactly like an iOS app would
  (chunk size and inter-chunk delay are adjustable).
- **Serial / device path** – writes the bytes to `/dev/cu.*` (sets the baud rate) or
  any writable device file.
- **Save to file** – for inspecting the bytes or sending them another way.

## Build

```bash
brew install xcodegen      # once
cd Tools/PrinterLab
xcodegen generate
open PrinterLab.xcodeproj
```

The generated project depends on the package at the repository root, so library
changes are picked up on the next build. Requires macOS 13 and Xcode 15.
