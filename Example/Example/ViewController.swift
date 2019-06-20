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

private extension TextBlock {

    static func plainText(_ content: String) -> TextBlock {
        return TextBlock(content: content, predefined: .light)
    }
}

class ViewController: UIViewController {

    let pm = PrinterManager()

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction func touchPrint(sender: UIButton) {

        guard let image = UIImage(named: "demo") else {
            return
        }

        if pm.canPrint {

            var receipt = Receipt(
                .title("Restaurant"),
                .blank,
                .text(.init("Palo Alto Californlia 94301")),
                .text(.init("378-0987893742")),
                .blank,
                .text(.init(content: Date().description, predefined: .alignment(.center))),
                .blank,
                .kv(key: "Merchant ID:", value: "iceu1390"),
                .kv(key: "Terminal ID:", value: "29383"),
                .blank,
                .kv(key: "Transaction ID:", value: "0x000321"),
                .text(.plainText("PURCHASE")),

                .blank,
                .kv(key: "Sub Total", value: "USD$ 25.09"),
                .kv(key: "Tip", value: "3.78"),
                .dividing,
                .kv(key: "Total", value: "USD$ 28.87"),
                .blank,
                .blank,
                .blank,
                .text(.init(content: "Thanks for supporting", predefined: .alignment(.center))),
                .text(.init(content: "local bussiness!", predefined: .alignment(.center))),
                .blank,
                .text(.init(content: "THANK YOU", predefined: .bold, .alignment(.center))),
                .blank,
                .blank,
                .blank,
                .qr("https://www.yuxiaor.com"),
                .blank,
                .blank
            )
            
            receipt.feedLinesOnTail = 2
            receipt.feedPointsPerLine = 60
            
            pm.print(receipt)
        } else {

            performSegue(withIdentifier: "ShowSelectPrintVC", sender: nil)
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let vc = segue.destination as? PrinterTableViewController {
            vc.sectionTitle = "Choose Printer"
            vc.printerManager = pm
        }
    }
}
