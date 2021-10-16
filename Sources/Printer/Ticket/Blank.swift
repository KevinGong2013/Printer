//
//  Blank.swift
//  Ticket
//
//  Created by gix on 2019/7/29.
//  Copyright © 2019 gix. All rights reserved.
//

import Foundation

struct Blank: BlockDataProvider {
    func data(using encoding: String.Encoding) -> Data {
        return Data()
    }
}
