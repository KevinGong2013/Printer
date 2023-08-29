//
//  PrinterTableViewController.swift
//  Printer
//
//  Created by gix on 12/8/16.
//  Copyright © 2016 Kevin. All rights reserved.
//

import UIKit

// swiftlint:disable type_name
public class BluetoothPrinterSelectTableViewController: UITableViewController {
    public weak var printerManager: BluetoothPrinterManager?

    public var sectionTitle: String? // convenience property

    var dataSource = [BluetoothPrinter]()

    override public func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")

        dataSource = printerManager?.nearbyPrinters ?? []
        printerManager?.delegate = self
    }

    override public func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource.count
    }

    override public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)

        guard indexPath.row < dataSource.count else {
            return cell
        }

        let printer = dataSource[indexPath.row]

        cell.textLabel?.text = printer.name ?? "unknow"
        cell.accessoryType = printer.state == .connected ? .checkmark : .none

        if printer.isConnecting {
            let v = UIActivityIndicatorView(style: .gray)
            v.startAnimating()
            cell.accessoryView = v
        } else {
            cell.accessoryView = nil
            cell.setEditing(false, animated: false)
        }

        return cell
    }

    override public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard printerManager != nil else {
            fatalError("printer manager must not be nil.")
        }
        return sectionTitle ?? "选择打印机"
    }

    override public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let p = dataSource[indexPath.row]

        if p.state == .connected {
            printerManager?.disconnect(p)
        } else {
            printerManager?.connect(p)
        }
    }
}

extension BluetoothPrinterSelectTableViewController: PrinterManagerDelegate {
    public func nearbyPrinterDidChange(_ change: NearbyPrinterChange) {
        tableView.beginUpdates()

        switch change {
        case let .add(p):
            let indexPath = IndexPath(row: dataSource.count, section: 0)
            dataSource.append(p)
            tableView.insertRows(at: [indexPath], with: .automatic)
        case let .update(p):
            guard let row = (dataSource.firstIndex { $0.identifier == p.identifier }) else {
                return
            }
            dataSource[row] = p
            let indexPath = IndexPath(row: row, section: 0)
            tableView.reloadRows(at: [indexPath], with: .automatic)
        case let .remove(identifier):
            guard let row = (dataSource.firstIndex { $0.identifier == identifier }) else {
                return
            }
            dataSource.remove(at: row)
            let indexPath = IndexPath(row: row, section: 0)
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }

        tableView.endUpdates()
    }
}
