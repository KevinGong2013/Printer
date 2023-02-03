//
//  ViewController.swift
//  Example
//
//  Created by GongXiang on 12/8/16.
//  Updated by Pradeep Sakharelia on 15/05/19
//  Copyright © 2016 Kevin. All rights reserved.
//

import UIKit
import Printer
import WebKit

class ViewController: UIViewController {

    private let bluetoothPrinterManager = BluetoothPrinterManager()
    private let dummyPrinter = DummyPrinter()
    
    @IBOutlet weak var webView: WKWebView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        dummyPrinter.ticketRender = self
    }
    
    @IBAction func touchPrint(sender: UIButton) {

        guard let image = UIImage(named: "demo"), let cgImage = image.cgImage else {
            return
        }
        
        let receipt = Receipt(.init(maxWidthDensity: 500, fontDesity: 12, encoding: .utf8))
        <<~ .style(.initialize)
        <<~ .page(.printAndFeed(lines: 3))
        <<~ .layout(.justification(.center))
        <<< Dividing.`default`()
        <<~ .style(.underlineMode(.enable2dot))
        <<< "Testing"
        <<< KV("k", "v")
        <<~ .style(.clear)
        <<< Image(cgImage)
        <<< Dividing.`default`()
        <<~ .page(.printAndFeed(lines: 0))
        <<~ .style(.initialize)
        <<< QRCode(content: "https://www.yuxiaor.com")
        <<~ .cursor(.lineFeed)
        <<< Command.cursor(.lineFeed)
        <<~ .cursor(.lineFeed)
        
        if bluetoothPrinterManager.canPrint {
            bluetoothPrinterManager.print(Data(receipt.data))
        }
        
        dummyPrinter.print(Data(receipt.data))
        
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
