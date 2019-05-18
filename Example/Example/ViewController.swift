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

class ViewController: UIViewController {

    let pm = PrinterManager()

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction func touchPrint(sender: UIButton) {

        let image = UIImage(named: "demo")!

        if pm.canPrint {

            var receipt = Receipt(
                .dividing,
                .qr("Icey.Liao"),
                .dividing,
                .image(image, attributes: [ImageBlock.PredefinedAttribute.alignment(.center)])
                //  Updated by Pradeep Sakharelia on 15/05/19
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
