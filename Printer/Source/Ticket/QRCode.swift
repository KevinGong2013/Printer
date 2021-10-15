//
//  QRCodeBlock.swift
//  Ticket
//
//  Created by gix on 2019/6/30.
//  Copyright © 2019 gix. All rights reserved.
//

import Foundation

struct QRCode: BlockDataProvider {
    
    let content: String
    
    init(_ content: String) {
        self.content = content
    }
    
    func data(using encoding: String.Encoding) -> Data {
        var result = Data()
        
        result.append(Data(esc_pos: ESC_POSCommand.justification(1),
                           ESC_POSCommand.QRSetSize(),
                           ESC_POSCommand.QRSetRecoveryLevel(),
                           ESC_POSCommand.QRGetReadyToStore(text: content)))
        
        if let cd = content.data(using: encoding) {
            result.append(cd)
        }
        
        result.append(Data(esc_pos: .QRPrint()))
        
        return result
    }
}
