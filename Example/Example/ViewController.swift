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

                "收据单".bc.title,
                "空行".bc.blank(),

                "1期账单·Kevin.Gong \n唐家湾 海怡湾畔 A座 402".bc.text,
                "分割线".bc.dividing,

                "费用详细".bc.kv(k: "费用类型", v: "代收余额"),
                
                1.bc.kv(k: "1租金(\u{FFE5} 89/月)", v: "\u{FFE5} 2,999.00"),
                "2017-08-09 至 2018-09-10".bc.text,
                "空行".bc.blank(),
                2.bc.kv(k: "2 服务费(\u{FFE5} 89/月)", v: "\u{FFE5} 2,999.00"),
                "2017-08-09 至 2018-09-10".bc.text,
                "空行".bc.blank(),
                3.bc.kv(k: "3 电费(\u{FFE5} 89/月)", v: "\u{FFE5} 2,999.00"),
                "2017-08-09 至 2018-09-10".bc.text,
                "空行".bc.blank(),
                "实收: 9,000.00\n实际付: 10,000.00".bc.text,
                "空行".bc.blank(),
                "签名:".bc.text,
                "空行".bc.blank(),
                "www.yuxiaor.com".bc.qr,
                1.bc.title,
                Character("_").bc.dividing
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
