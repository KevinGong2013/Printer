//
//  ViewController.swift
//  Example
//
//  Created by GongXiang on 12/8/16.
//  Copyright © 2016 Kevin. All rights reserved.
//

import UIKit
import Printer

class ViewController: UIViewController {

    let pm = PrinterManager()

    override func viewDidLoad() {
        super.viewDidLoad()

    }

    @IBAction func touchPrint(sender: UIButton) {

        if pm.canPrint {

            var receipt = Receipt(
                .title("title".uppercased()),
                .blank,
                .dividing,
                .kv(key: "Key", value: "Value-- Style"),
                .kv(key: "1", value: "2"),
                .kv(key: "a", value: "b"),
                .kv(key: "cat", value: "dog"),
                .blank,
                .dividing,
                .title("QRCode"),
                .qr("https://www.yuxiaor.com"),
                .dividing
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
