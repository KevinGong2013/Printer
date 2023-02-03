
# ESC/POS Printer Driver for Swift

# Description

Swift ticket printer framework for ESC/POS-compatible thermal printers

## Requirements

* iOS 12.0+
* Swift 5.3+

## Installation

### CocoaPods

#### iOS 12 and newer

Printer is available on CocoaPods. Simply add the following line to your podfile:

``` shell

# For latest release in cocoapods
pod 'Printer', :git => 'https://github.com/KevinGong2013/Printer.git', :branch => 'refactor'

```

## Getting Started

### Import

```swift
import Printer

```

### Create ESC/POS Ticket

``` swift

    let receipt = Receipt(.🖨️58(.ascii))
    <<~ .style(.initialize)
    <<< Image(cgImage)
    <<< "Testing"
    <<< "Testing"
    <<< KV("k", "v")
    <<~ .style(.clear)
    <<< Image(cgImage, grayThreshold: 28)
    <<< Dividing.`default`()
    <<~ .page(.printAndFeed(lines: 0))
    <<~ .style(.initialize)
    <<< QRCode(content: "https://www.apple.com")
    <<~ .style(.underlineMode(.enable2dot))
    <<~ .page(.printAndFeed(lines: 10))
    
    printer.write(Data(receipt.data))

```

### Write Ticket to Hardware

``` swift

// connect your pirnter&print ticket.
private let bluetoothPrinterManager = BluetoothPrinterManager()
private let dummyPrinter = DummyPrinter()

 if bluetoothPrinterManager.canPrint {
    bluetoothPrinterManager.write(ticket)
  }
dummyPrinter.write(ticket)

```

### Receipt

[TODO]

### Notes

* Send data to your own Bluetooth Manager is possible
