//
//  SessionClient.swift
//  SwiftAlpsSecDemo
//
//  Created by Anastasiia on 11/8/16.
//  Copyright © 2016 Anastasiia Vxtl. All rights reserved.
//

import Foundation

let errorDomain = "com.themisserver.example"

final class Transport: TSSessionTransportInterface {

    fileprivate var serverId: String?
    fileprivate var serverPublicKeyData: Data?

    func setupKeys(_ serverId: String, serverPublicKey: String) {
        self.serverId = serverId
        self.serverPublicKeyData = Data(base64Encoded: serverPublicKey,
                options: .ignoreUnknownCharacters)
    }

    override func publicKey(for binaryId: Data!) throws -> Data {
        let error: Error = NSError(domain: errorDomain, code: -1, userInfo: nil)
        let stringFromData = String(data: binaryId, encoding: String.Encoding.utf8)
        if stringFromData == nil {
            throw error
        }

        if stringFromData == serverId {
            guard let resultData: Data = serverPublicKeyData else {
                throw error
            }
            return resultData
        }
        return Data()
    }
}


final class SessionDemo {
    
    let baseURL: String = "http://alps.cossacklabs.com/"
    
    var transport: Transport?
    var session: TSSession?
    
    // client id should be unique per session
    let kClientId: String = "my_demo_app_#\(arc4random_uniform(100000))"
    
    // get from server
    let kServerId: String = "server"
    let kServerPublicKey: String = "VUVDMgAAAC1fJTg6AtFORuzUPkI0jpAUylTNmW1N9NOl4LPONX0EQuVUc1Xb"


    func runDemo() {
        let (clientPrivateKeyOptional, clientPublicKeyOptional) = generateClientKeys()
        guard let clientPrivateKey = clientPrivateKeyOptional, let clientPublicKey = clientPublicKeyOptional else {
            return
        }

        print("EC privateKey = \(clientPrivateKey)")
        print("EC publicKey = \(clientPublicKey)")
        print("clientId = \(kClientId)")
        
        checkKeysNotEmpty()

        let messageToSend = "Hello, Swift Alps!"

        print("Sending discovery message")
        sendDiscoveryMessage(clientPublicKey: clientPublicKey, completion: {
            (data: Data?, error: Error?) -> Void in

            if data != nil {
                print("Sending payload message")
                self.sendPayload(clientPrivateKey: clientPrivateKey, messageToSend: messageToSend)
            }

        })

    }


    fileprivate func sendDiscoveryMessage(clientPublicKey: String,
                                          completion: @escaping (_ data: Data?, _ error: Error?) -> Void) {

        postDiscoveryMessageTo(baseURL:baseURL,
                                clientId: kClientId,
                                clientPublicKey: clientPublicKey,
                                completion: completion)

    }


    fileprivate func sendPayload(clientPrivateKey: String, messageToSend: String) {

        guard let clientIdData: Data = kClientId.data(using: String.Encoding.utf8),
        let clientPrivateKeyData: Data = Data(base64Encoded: clientPrivateKey,
                options: .ignoreUnknownCharacters) else {

            print("Error occurred during base64 encoding", #function)
            return
        }

        self.transport = Transport()
        self.transport?.setupKeys(kServerId, serverPublicKey: kServerPublicKey)
        self.session = TSSession(userId: clientIdData, privateKey: clientPrivateKeyData, callbacks: self.transport)


        var connectionMessage: Data
        do {
            guard let resultOfConnectionRequest = try session?.connectRequest() else {
                throw NSError(domain: errorDomain, code: -2, userInfo: nil)
            }

            connectionMessage = resultOfConnectionRequest
        } catch let error {
            print("Error occurred while connecting to session \(error)", #function)
            return
        }

        self.startSession(message: connectionMessage, completion: {
            (error: Error?) -> Void in

            if error != nil {
                print("Error occurred while session initialization \(error)", #function)
                return
            }

            self.encryptAndSendPayload(message: messageToSend,
                    completion: {
                        (data: String?, messageError: Error?) -> Void in

                        guard let data = data else {
                            print("Error occurred while sending message \(messageError)", #function)
                            return
                        }
                        print("Response success:\n\(data)")
                    })
        })
    }
    
    
    fileprivate func startSession(message: Data,
                                    completion: @escaping (_ error: Error?) -> Void) {


        postEncryptedMessageTo(baseURL: baseURL, message: message,
                               completion: {
                                   (data: Data?, error: Error?) -> Void in

            guard let data = data else {
                print("Error occurred while starting session \(error)")
                return
            }

            do {
                guard let decryptedMessage = try self.session?.unwrapData(data) else {
                    throw NSError(domain: errorDomain, code: -4, userInfo: nil)
                }

                if let session = self.session, session.isSessionEstablished() == true {
                    print("Session established!")
                    completion(nil)
                } else {
                    self.startSession(message: decryptedMessage, completion: completion)
                }

            } catch let error {
                // frustrating, but 'unwrapData' can return nil without error (and it's okay)
                // Swift returns error "Foundation._GenericObjCError"
                if let session = self.session, session.isSessionEstablished() == true {
                    print("Session established!")
                    completion(nil)
                } else {
                    print("Error occurred while decrypting session start message \(error)", #function)
                    completion(error)
                }
                return
            }
        })
    }
    
    
    fileprivate func encryptAndSendPayload(message: String,
                                   completion: @escaping (_ data: String?, _ error: Error?) -> Void) {
        var encryptedMessage: Data
        do {
            guard let wrappedMessage: Data = try self.session?.wrap(message.data(using: String.Encoding.utf8)) else {
                print("Error occurred during wrapping message ", #function)
                return
            }
            encryptedMessage = wrappedMessage
        } catch let error {
            print("Error occurred while wrapping message \(error)", #function)
            completion(nil, error)
            return
        }

        postEncryptedMessageTo(baseURL: baseURL, message: encryptedMessage, completion: {(data: Data?, error: Error?) -> Void in
            guard let data = data else {
                print("Error occurred while sending message \(error)")
                return
            }

            do {
                guard let decryptedMessage: Data = try self.session?.unwrapData(data),
                        let resultString: String = String(data: decryptedMessage, encoding: String.Encoding.utf8) else {

                    throw NSError(domain: errorDomain, code: -3, userInfo: nil)
                }
                completion(resultString, nil)

            } catch let error {
                print("Error occurred while decrypting message \(error)", #function)
                completion(nil, error)
                return
            }
        })
    }
}


// Keys
extension SessionDemo {
    fileprivate func generateClientKeys() -> (String?, String?) {
        guard let keyGeneratorEC: TSKeyGen = TSKeyGen(algorithm: .EC) else {
            print("Error occurred while initializing object keyGeneratorEC", #function)
            return (nil, nil)
        }
        let privateKeyEC: Data = keyGeneratorEC.privateKey as Data
        let publicKeyEC: Data = keyGeneratorEC.publicKey as Data

        let privateKeyECString = privateKeyEC.base64EncodedString(options: .lineLength64Characters)
        let publicKeyECString = publicKeyEC.base64EncodedString(options: .lineLength64Characters)

        return (privateKeyECString, publicKeyECString)
    }


    fileprivate func checkKeysNotEmpty() {
        assert(!(kServerPublicKey == "<server public key>"), "Get server key from http://alps.cossacklabs.com/")

        assert(!(kClientId == "<client id>"), "Set client id")
        assert(!(kServerId == "<server id>"), "Set server id")

    }
}


// Networking
extension SessionDemo {
    fileprivate func postDiscoveryMessageTo(baseURL: String,
                                         clientId: String,
                                         clientPublicKey:String,
                                         completion: @escaping (_ data: Data?, _ error: Error?) -> Void) {

        let path: String = baseURL + "connect_request"

        let escapedClientId: String = clientId.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
        let escapedPublicKey: String = clientPublicKey.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
        let params: String = "\("client_name=")\(escapedClientId)&\("public_key=")\(clientPublicKey)"
        
        postRequestTo(path, body: params, completion: completion)
    }


    fileprivate func postEncryptedMessageTo(baseURL: String,
                                        message: Data,
                                        completion: @escaping (_ data: Data?, _ error: Error?) -> Void) {

        let path: String = baseURL + "message"
        let base64URLEncodedMessage: String = message.base64EncodedString(options: .endLineWithLineFeed)
            .addingPercentEncoding(withAllowedCharacters: CharacterSet.alphanumerics)!

        let base64Body: String = "\("message=")\(base64URLEncodedMessage)"

        postRequestTo(path, body: base64Body, completion: completion)
    }
    
    
    fileprivate func postRequestTo(_ path: String, body: String, completion: @escaping (_ data: Data?, _ error: Error?) -> Void) {
        let url: URL = URL(string: path)!
        let config: URLSessionConfiguration = URLSessionConfiguration.default
        let session: URLSession = URLSession(configuration: config)
        
        let request: NSMutableURLRequest = NSMutableURLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-type")
        
        let bodyData: Data = body.data(using: String.Encoding.utf8)!

        print("body=\n\(body)")
        
        let uploadTask: URLSessionDataTask = session.uploadTask(with: request as URLRequest, from: bodyData,
            completionHandler: {
                (data: Data?, response: URLResponse?, error: Error?) -> Void in
                
                print("response=\n\(response)")
                
                if error != nil {
                    completion(nil, error)
                    return
                }
                
                guard let data = data else {
                    print("Oops, response = \(response)\n error = \(error)")
                    completion(nil, error)
                    return
                }

                if let response = response as? HTTPURLResponse, response.statusCode != 200 {
                    print("Oops, response = \(response)\n error = \(error)")
                    completion(nil, error)
                    return
                }
                
                print("data=\n\(String(data: data, encoding: .utf8))")
                completion(data, nil)
                return
        })
        
        uploadTask.resume()
    }
}
