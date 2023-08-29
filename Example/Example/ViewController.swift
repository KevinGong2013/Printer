//
//  ViewController.swift
//  Example
//
//  Created by GongXiang on 12/8/16.
//  Copyright © 2016 Kevin. All rights reserved.
//

import Printer
import UIKit
import WebKit

class ViewController: UIViewController {
    private let bluetoothPrinterManager = BluetoothPrinterManager()
    private let dummyPrinter = DummyPrinter()
    
    @IBOutlet var webView: WKWebView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        dummyPrinter.ticketRender = self
    }
    
    @IBAction func touchPrint(sender: UIButton) {
        guard let image = UIImage(named: "demo"), let cgImage = image.cgImage else {
            return
        }
             
        let receipt = Receipt(.init(maxWidthDensity: 500, fontDensity: 12, encoding: .utf8))
            <<~ .style(.initialize)
            <<~ .page(.printAndFeed(lines: 3))
            <<~ .layout(.justification(.center))
            <<< Dividing.default()
            <<~ .style(.underlineMode(.enable2dot))
            <<< "Testing"
            <<< KVItem("k", "v")
            <<~ .style(.clear)
            <<< Image(cgImage, grayThreshold: 28)
            <<< Dividing.default()
            <<~ .page(.printAndFeed(lines: 0))
            <<~ .style(.initialize)
            <<< QRCode(content: "https://www.yuxiaor.com")
            <<~ .cursor(.lineFeed)
            <<< Command.cursor(.lineFeed)
            <<~ .cursor(.lineFeed)
        
        if bluetoothPrinterManager.canPrint {
            bluetoothPrinterManager.write(Data(receipt.data))
        }
        
        dummyPrinter.write(Data(receipt.data))
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let vc = segue.destination as? BluetoothPrinterSelectTableViewController {
            vc.sectionTitle = "Choose Bluetooth Printer"
            vc.printerManager = bluetoothPrinterManager
        }
    }
}

extension ViewController: TicketRender {
    func printerDidGenerate(_ printer: DummyPrinter, html htmlTicket: String) {
        DispatchQueue.main.async { [weak self] in
            self?.webView.loadHTMLString(htmlTicket, baseURL: nil)
        }
//        debugPrint(htmlTicket)
    }
}
