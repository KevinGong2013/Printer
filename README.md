
# ESC/POS Printer Driver for Swift

# Description
Swift ticket printer framework for ESC/POS-compatible thermal printers


### Features
* Supports connect bluetooth printer.
* Crate printable ticket easily.

## Requirements
* iOS 9.0+
* Swift 5.0

## Installation
### CocoaPods
#### iOS 9 and newer
Printer is available on CocoaPods. Simply add the following line to your podfile:

```
# For latest release in cocoapods
pod 'Printer'
```

### Carthage

```
github "KevinGong2013/Printer"
```

## Getting Started
### Import

```swift
import Printer

```

### Create ESC/POS Ticket

``` swift 

var ticket = Ticket(
            .title("Restaurant"),
            .blank,
            .plainText("Palo Alto Californlia 94301"),
            .plainText("378-0987893742"),
            .blank,
            .image(image, attributes: .alignment(.center)),
            .text(.init(content: Date().description, predefined: .alignment(.center))),
            .blank,
            .kv(k: "Merchant ID:", v: "iceu1390"),
            .kv(k: "Terminal ID:", v: "29383"),
            .blank,
            .kv(k: "Transaction ID:", v: "0x000321"),
            .plainText("PURCHASE"),
            .blank,
            .kv(k: "Sub Total", v: "USD$ 25.09"),
            .kv(k: "Tip", v: "3.78"),
            .dividing,
            .kv(k: "Total", v: "USD$ 28.87"),
            .blank(3),
            Block(Text(content: "Thanks for supporting", predefined: .alignment(.center))),
            .blank,
            
            .text(.init(content: "THANK YOU", predefined: .bold, .alignment(.center))),
            .blank(3),
            .qr("https://www.yuxiaor.com")
        )
        
        ticket.feedLinesOnHead = 2
        ticket.feedLinesOnTail = 3

```

### Write Ticket to Hardware

``` swift

// connect your pirnter&print ticket.
private let bluetoothPrinterManager = BluetoothPrinterManager()
private let dummyPrinter = DummyPrinter()

 if bluetoothPrinterManager.canPrint {
    bluetoothPrinterManager.print(ticket)
  }
dummyPrinter.print(ticket)

```

### Ticket && Blocks
[TODO]
