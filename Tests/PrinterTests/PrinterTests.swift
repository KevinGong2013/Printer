//
//  PrinterTests.swift
//  PrinterTests
//

import CoreGraphics
@testable import Printer
import XCTest

final class ReceiptTests: XCTestCase {
    let profile = PrinterProfile.🖨️58(.utf8)

    func testTextAppendsLineFeed() {
        XCTAssertEqual("Hi".assemblePrintableData(profile), [0x48, 0x69, 10])
    }

    func testTextWithoutLineFeed() {
        XCTAssertEqual(Text("Hi").assemblePrintableData(profile), [0x48, 0x69])
    }

    func testUnencodableTextIsNotDroppedSilently() {
        let ascii = PrinterProfile.🖨️58(.ascii)
        let bytes = "€5".assemblePrintableData(ascii)
        XCTAssertFalse(bytes.isEmpty)
        XCTAssertEqual(bytes.last, 10)
        XCTAssertTrue(bytes.contains(0x35)) // the "5" survives
    }

    func testGBEncodingForChinese() {
        let gb = PrinterProfile.🖨️58(String.GBEncoding.GB_18030_2000)
        XCTAssertEqual("中".assemblePrintableData(gb), [0xD6, 0xD0, 10])
    }

    func testKVItemFillsExactlyOneLine() {
        let bytes = KVItem("Total", "¥12.00").assemblePrintableData(profile)
        let line = String(decoding: bytes.dropLast(), as: UTF8.self)
        XCTAssertEqual(line.count, profile.charactersPerLine)
        XCTAssertTrue(line.hasPrefix("Total"))
        XCTAssertTrue(line.hasSuffix("¥12.00"))
    }

    func testKVItemCountsCJKAsDoubleWidth() {
        let bytes = KVItem("合计", "12").assemblePrintableData(profile)
        let line = String(decoding: bytes.dropLast(), as: UTF8.self)
        XCTAssertEqual(line.printableWidth, profile.charactersPerLine)
    }

    func testDividingIsFullWidth() {
        let bytes = Dividing.default().assemblePrintableData(profile)
        XCTAssertEqual(bytes.count, profile.charactersPerLine + 1)
        XCTAssertEqual(Set(bytes.dropLast()), [UInt8(ascii: "-")])
    }

    func testOperatorsConcatenateInOrder() {
        let receipt = Receipt(profile)
            <<~ .style(.initialize)
            <<< "A"
            <<~ .page(.printAndFeed(lines: 2))
        XCTAssertEqual(receipt.data, [27, 64, 0x41, 10, 27, 100, 2])
        XCTAssertEqual(receipt.bytes, Data(receipt.data))
    }
}

final class CommandTests: XCTestCase {
    func testCodePageUsesESCt() {
        XCTAssertEqual(Command.style(.selectCharacterCodePage(.wpc1252)).value, [27, 116, 16])
        XCTAssertEqual(Command.style(.selectCharacterCodePage(.pc437)).value, [27, 116, 0])
        XCTAssertEqual(Command.style(.selectCharacterCodePage(.wpc1256)).value, [27, 116, 50])
    }

    func testCutsUseGSV() {
        XCTAssertEqual(Command.page(.fullCut).value, [29, 86, 0])
        XCTAssertEqual(Command.page(.partialCut).value, [29, 86, 1])
        XCTAssertEqual(Command.page(.feedAndCut(partial: true, feed: 30)).value, [29, 86, 66, 30])
        XCTAssertEqual(Command.page(.legacyCut(partial: false)).value, [27, 105])
    }

    func testCashDrawer() {
        XCTAssertEqual(Command.peripheral(.cashDrawer()).value, [27, 112, 0, 50, 250])
        XCTAssertEqual(Command.peripheral(.cashDrawer(pin: 1, onTime: 25, offTime: 250)).value, [27, 112, 1, 25, 250])
    }

    func testCharacterSizeClampsAndPacks() {
        XCTAssertEqual(Command.style(.characterSize(width: 2, height: 3)).value, [29, 33, 0x12])
        XCTAssertEqual(Command.style(.characterSize(width: 0, height: 99)).value, [29, 33, 0x07])
    }

    func testMarginsAreLittleEndian() {
        XCTAssertEqual(Command.layout(.leftMargin(300)).value, [29, 76, 44, 1])
        XCTAssertEqual(Command.layout(.printAreaWidth(576)).value, [29, 87, 64, 2])
    }

    func testRawPassesThrough() {
        XCTAssertEqual(Command.raw([1, 2, 3]).value, [1, 2, 3])
    }
}

final class QRCodeTests: XCTestCase {
    func testCommandSequence() {
        let bytes = QRCode(content: "ab", moduleSize: 4, recovery: .h).assemblePrintableData(.🖨️58(.utf8))
        let expected: [UInt8] = [
            29, 40, 107, 4, 0, 49, 65, 50, 0, // model 2
            29, 40, 107, 3, 0, 49, 67, 4, // module size 4
            29, 40, 107, 3, 0, 49, 69, 51, // level H
            29, 40, 107, 5, 0, 49, 80, 48, 0x61, 0x62, // store "ab" (pL = 2 + 3)
            29, 40, 107, 3, 0, 49, 81, 48, // print
        ]
        XCTAssertEqual(bytes, expected)
    }

    func testModuleSizeIsClamped() {
        XCTAssertEqual(QRCode(content: "x", moduleSize: 0).moduleSize, 1)
        XCTAssertEqual(QRCode(content: "x", moduleSize: 99).moduleSize, 16)
    }

    func testLengthHighByte() {
        let content = String(repeating: "a", count: 300)
        let bytes = QRCode(content: content).assemblePrintableData(.🖨️58(.utf8))
        guard let store = bytes.firstRange(of: [49, 80, 48]) else {
            return XCTFail("store command missing")
        }
        let pL = bytes[store.lowerBound - 2], pH = bytes[store.lowerBound - 1]
        XCTAssertEqual(Int(pL) + Int(pH) * 256, 303)
    }

    func testEncodingOverride() {
        let bytes = QRCode(content: "中", encoding: .utf8).assemblePrintableData(.🖨️58(.ascii))
        XCTAssertTrue(bytes.contains([0xE4, 0xB8, 0xAD]))
    }
}

final class BarcodeTests: XCTestCase {
    func testCode128AddsCodeSetB() {
        let bytes = Barcode("AB", height: 60, moduleWidth: 2, text: .none).assemblePrintableData(.🖨️58())
        XCTAssertEqual(bytes, [29, 104, 60, 29, 119, 2, 29, 72, 0, 29, 102, 0, 29, 107, 73, 4, 123, 66, 0x41, 0x42])
    }

    func testEAN13() {
        let bytes = Barcode("4901234567894", symbology: .ean13).assemblePrintableData(.🖨️58())
        XCTAssertEqual(Array(bytes.suffix(17)), [29, 107, 67, 13] + Array("4901234567894".utf8))
    }

    func testNonASCIIIsRejected() {
        XCTAssertTrue(Barcode("中").assemblePrintableData(.🖨️58()).isEmpty)
    }
}

final class ImageTests: XCTestCase {
    /// Builds an RGBA image of `width`×`height`, white, with the left half black.
    private func makeImage(width: Int, height: Int, alpha: Bool = true, leftHalfBlack: Bool = true) -> CGImage {
        let space = CGColorSpaceCreateDeviceRGB()
        let info = alpha ? CGImageAlphaInfo.premultipliedLast.rawValue : CGImageAlphaInfo.noneSkipLast.rawValue
        let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                            bytesPerRow: 0, space: space, bitmapInfo: info)!
        ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        if leftHalfBlack {
            ctx.setFillColor(red: 0, green: 0, blue: 0, alpha: 1)
            ctx.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
        }
        return ctx.makeImage()!
    }

    func testHeaderAndBlackIsOne() {
        let image = makeImage(width: 16, height: 2)
        let bytes = ImageItem(image).assemblePrintableData(.🖨️58())
        XCTAssertEqual(Array(bytes.prefix(8)), [29, 118, 48, 0, 2, 0, 2, 0])
        XCTAssertEqual(Array(bytes.dropFirst(8)), [0xFF, 0x00, 0xFF, 0x00])
    }

    func testWhiteImageIsAllZero() {
        let image = makeImage(width: 8, height: 1, leftHalfBlack: false)
        XCTAssertEqual(ImageItem(image).assemblePrintableData(.🖨️58()), [29, 118, 48, 0, 1, 0, 1, 0, 0])
    }

    func testNonMultipleOf8WidthIsPadded() {
        let image = makeImage(width: 10, height: 1)
        let bytes = ImageItem(image).assemblePrintableData(.🖨️58())
        XCTAssertEqual(bytes[4 ... 7], [2, 0, 1, 0])
        XCTAssertEqual(Array(bytes.suffix(2)), [0xF8, 0x00])
    }

    func testRGBWithoutAlphaDoesNotCrash() {
        let image = makeImage(width: 8, height: 1, alpha: false)
        XCTAssertEqual(ImageItem(image).assemblePrintableData(.🖨️58()).last, 0xF0)
    }

    func testGrayscaleSourceDoesNotCrash() {
        let ctx = CGContext(data: nil, width: 8, height: 1, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        ctx.setFillColor(gray: 0, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: 8, height: 1))
        XCTAssertEqual(ImageItem(ctx.makeImage()!).assemblePrintableData(.🖨️58()).last, 0xFF)
    }

    func testWideImageIsScaledToPaper() {
        let image = makeImage(width: 1000, height: 100)
        let bytes = ImageItem(image, rowsPerBand: 0).assemblePrintableData(.🖨️58())
        XCTAssertEqual(bytes[4 ... 7], [48, 0, 38, 0]) // 384 px = 48 bytes, 100 * 384/1000 ≈ 38 rows
        XCTAssertEqual(bytes.count, 8 + 48 * 38)
    }

    func testDoubleWidthHalvesTargetWidth() {
        let image = makeImage(width: 1000, height: 10)
        XCTAssertEqual(ImageItem(image, mode: .doubleWH).targetWidth(for: .🖨️58()), 192)
    }

    func testScalingNoneKeepsNativeSize() {
        let image = makeImage(width: 1000, height: 1)
        let bytes = ImageItem(image, scaling: .none, rowsPerBand: 0).assemblePrintableData(.🖨️58())
        XCTAssertEqual(bytes[4 ... 5], [125, 0])
    }

    func testLongImageIsSplitIntoBands() {
        let image = makeImage(width: 8, height: 150)
        let bytes = ImageItem(image, rowsPerBand: 64).assemblePrintableData(.🖨️58())
        // 64 + 64 + 22 rows, each band has an 8-byte header and 1 byte per row.
        XCTAssertEqual(bytes.count, 3 * 8 + 150)
        XCTAssertEqual(Array(bytes.prefix(8)), [29, 118, 48, 0, 1, 0, 64, 0])
        XCTAssertEqual(Array(bytes[(8 + 64 + 8 + 64) ..< (8 + 64 + 8 + 64 + 8)]), [29, 118, 48, 0, 1, 0, 22, 0])
    }

    func testDitherOfMidGrayIsRoughlyHalfBlack() {
        let ctx = CGContext(data: nil, width: 64, height: 64, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        ctx.setFillColor(gray: 0.5, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        let bytes = ImageItem(ctx.makeImage()!, binarization: .dither, rowsPerBand: 0).assemblePrintableData(.🖨️58())
        let black = bytes.dropFirst(8).reduce(0) { $0 + $1.nonzeroBitCount }
        XCTAssertEqual(Double(black) / 4096, 0.5, accuracy: 0.05)
        // A plain threshold would make this either all black or all white.
        let thresholded = ImageItem(ctx.makeImage()!, rowsPerBand: 0).assemblePrintableData(.🖨️58())
        XCTAssertTrue(Set(thresholded.dropFirst(8)).count == 1)
    }

    func testBase64Init() {
        // 1×1 white PNG
        let png = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII="
        XCTAssertNotNil(ImageItem(base64: "data:image/png;base64," + png))
        XCTAssertNotNil(ImageItem(base64: png))
        XCTAssertNil(ImageItem(base64: "not base64!!"))
    }
}

final class DummyPrinterTests: XCTestCase {
    func testRecordsHistory() {
        let printer = DummyPrinter()
        printer.logsToConsole = false
        var seen = [Data]()
        printer.onWrite = { seen.append($0) }
        printer.write(Receipt(.🖨️58()) <<< "x")
        XCTAssertEqual(printer.history, [Data([0x78, 10])])
        XCTAssertEqual(seen, printer.history)
    }
}
