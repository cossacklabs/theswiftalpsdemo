//
//  CellDemo.swift
//  SwiftAlpsSecDemo
//
//  Created by Anastasiia on 11/8/16.
//  Copyright © 2016 Anastasiia Vxtl. All rights reserved.
//

import Foundation


final class CellDemo {

    let message: String = "All your base are belong to us!"
    let context: String = "For great justice"
    let mySecretPassword: String = "Super secret pass tell nobody"


    func runDemo() {

        guard let cell = initializeCell(password: mySecretPassword) else {
            return
        }

        guard let encryptedMessage = encryptMessage(cell: cell, message: message, context: context) else {
            return
        }

        let encrypedMessageString = encryptedMessage.base64EncodedString(options: .lineLength64Characters)
        print("encryptedMessage = \(encrypedMessageString)")

        guard let decryptedMessage = decryptMessage(cell: cell, encryptedMessage: encryptedMessage, context: context) else {
            return
        }

        print("decryptedMessage = \(decryptedMessage)")
    }


    private func initializeCell(password: String) -> TSCellSeal? {
        let masterKeyData = password.data(using: .utf8)!
        guard let cellSeal: TSCellSeal = TSCellSeal(key: masterKeyData) else {
            print("Error occurred while initializing object cellSeal", #function)
            return nil
        }
        return cellSeal
    }


    func encryptMessage(cell: TSCellSeal, message: String, context: String) -> Data? {

        var encryptedMessage: Data = Data()
        do {
            encryptedMessage = try cell.wrap(message.data(using: .utf8)!,
                    context: context.data(using: .utf8))

        } catch let error as NSError {
            print("Error occurred while encrypting \(error)", #function)
            return nil
        }
        return encryptedMessage
    }


    func decryptMessage(cell: TSCellSeal, encryptedMessage: Data, context: String) -> String? {

        var decryptedMessage: Data = Data()
        do {
            decryptedMessage = try cell.unwrapData(encryptedMessage,
                    context: context.data(using: .utf8))
        } catch let error as NSError {
            print("Error occurred while decrypting \(error)", #function)
            return nil
        }

        let resultString: String? = String(data: decryptedMessage, encoding: .utf8)
        return resultString
    }

}
