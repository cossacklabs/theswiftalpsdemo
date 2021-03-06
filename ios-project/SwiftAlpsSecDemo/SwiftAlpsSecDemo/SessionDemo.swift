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

    private var serverId: String?
    private var serverPublicKeyData: Data?

    func setupKeys(_ serverId: String, serverPublicKey: String) {
        self.serverId = serverId
        self.serverPublicKeyData = Data(base64Encoded: serverPublicKey,
                options: .ignoreUnknownCharacters)
    }

    override func publicKey(for binaryId: Data!) throws -> Data {
        let error: Error = NSError(domain: errorDomain, code: -1, userInfo: nil)
        guard let stringFromData = String(data: binaryId, encoding: String.Encoding.utf8) else {
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

    enum Constants: String {
        case BaseURL = "http://alps.cossacklabs.com/"

        // get from server
        case ServerId = "server"
        case ServerPublicKey = "VUVDMgAAAC0yt34XAzBC7wOkxVM2WSJOUlneL4TLMaVRK9doGUewM3qOoFKL"
        
        // client id should be unique per session
        case ClientId = "swift_developer"
    }
    

    private var transport: Transport?
    private var session: TSSession?

    private let messageToSend: String = "Hello, Swift Alps! 🧀🍷"


    func runDemo() {
        let (clientPrivKey, clientPubKey, clientIdRand) = generateClientKeys(clientId: Constants.ClientId.rawValue)
        guard let clientPrivateKey = clientPrivKey, let clientPublicKey = clientPubKey,
            let clientId = clientIdRand else {
            return
        }

        print("Generated eys: ")
        print("EC privateKey = \(clientPrivateKey)")
        print("EC publicKey = \(clientPublicKey)")
        print("clientId = \(clientId)")

        print("\n\nSending discovery message..")

        sendDiscoveryMessage(clientId: clientId, clientPublicKey: clientPublicKey) {
                                
            (data: Data?, error: Error?) -> Void in

            guard data != nil else { return }

            print("\n\nEstablishing session...")
            self.sendPayload(serverId: Constants.ServerId.rawValue, serverPublicKey: Constants.ServerPublicKey.rawValue,
                             clientId: clientId, clientPrivateKey: clientPrivateKey,
                             messageToSend: self.messageToSend)

        }

    }


    fileprivate func sendDiscoveryMessage(clientId: String, clientPublicKey: String,
                                          completion: @escaping (_ data: Data?, _ error: Error?) -> Void) {

        postDiscoveryMessageFrom(clientId: clientId,
                                clientPublicKey: clientPublicKey,
                                completion: completion)

    }


    fileprivate func sendPayload(serverId: String, serverPublicKey: String, clientId: String,
                                 clientPrivateKey: String, messageToSend: String) {

        guard let clientIdData: Data = clientId.data(using: .utf8),
        let clientPrivateKeyData: Data = Data(base64Encoded: clientPrivateKey,
                options: .ignoreUnknownCharacters) else {

            print("💥 Error occurred during base64 encoding", #function)
            return
        }

        self.transport = Transport()
        self.transport?.setupKeys(serverId, serverPublicKey: serverPublicKey)
        self.session = TSSession(userId: clientIdData, privateKey: clientPrivateKeyData, callbacks: self.transport!)


        var connectionMessage: Data
        do {
            guard let resultOfConnectionRequest = try session?.connectRequest() else {
                throw NSError(domain: errorDomain, code: -2, userInfo: nil)
            }

            connectionMessage = resultOfConnectionRequest
        } catch let error {
            print("💥 Error occurred while connecting to session \(error)", #function)
            return
        }

        self.startSession(clientId: clientId, message: connectionMessage) {
            (error: Error?) -> Void in

            if error != nil {
                print("💥 Error occurred while session initialization \(error as Optional)", #function)
                return
            }

            print("\n\nSending payload message...")
            self.encryptAndSendPayload(message: messageToSend, clientId: clientId)
                   {
                        (data: String?, messageError: Error?) -> Void in

                        guard let data = data else {
                            print("💥 Error occurred while sending message \(messageError as Optional)", #function)
                            return
                        }
                        print("\n\n👏 Server response success:\n\(data)")
                    }
        }
    }
    
    
    fileprivate func startSession(clientId: String, message: Data,
                                    completion: @escaping (_ error: Error?) -> Void) {


        postEncryptedMessage(message: message, clientId: clientId) { (data: Data?, error: Error?) -> Void in

            guard let data = data else {
                print("💥 Error occurred while starting session \(error as Optional)")
                return
            }

            do {
                guard let decryptedMessage = try self.session?.unwrapData(data) else {
                    throw NSError(domain: errorDomain, code: -4, userInfo: nil)
                }

                if let session = self.session, session.isSessionEstablished() == true {
                    print("\n\n🙃 Session established!\n")
                    completion(nil)
                } else {
                    self.startSession(clientId: clientId, message: decryptedMessage, completion: completion)
                }

            } catch let error {
                // frustrating, but 'unwrapData' can return nil without error (and it's okay)
                // Swift returns error "Foundation._GenericObjCError"
                if let session = self.session, session.isSessionEstablished() == true {
                    print("\n\n🙃 Session established!\n")
                    completion(nil)
                } else {
                    print("💥 Error occurred while decrypting session start message \(error)", #function)
                    completion(error)
                }
            }
        }
    }
    
    
    fileprivate func encryptAndSendPayload(message: String, clientId: String,
                                   completion: @escaping (_ data: String?, _ error: Error?) -> Void) {
        
        var encryptedMessage: Data = Data()
        do {
            guard let wrappedMessage: Data = try self.session?.wrap(message.data(using: .utf8)) else {
                print("💥 Error occurred during wrapping message ", #function)
                return
            }
            encryptedMessage = wrappedMessage
        } catch let error {
            print("💥 Error occurred while wrapping message \(error)", #function)
            completion(nil, error)
            return
        }

        postEncryptedMessage(message: encryptedMessage, clientId: clientId) { (data: Data?, error: Error?) -> Void in
                                
            guard let data = data else {
                print("💥 Error occurred while sending message \(error as Optional)")
                return
            }

            do {
                guard let decryptedMessage: Data = try self.session?.unwrapData(data),
                        let resultString: String = String(data: decryptedMessage, encoding: .utf8) else {

                    throw NSError(domain: errorDomain, code: -3, userInfo: nil)
                }
                completion(resultString, nil)

            } catch let error {
                print("💥 Error occurred while decrypting message \(error)", #function)
                completion(nil, error)
            }
        }
    }
}


// Keys
extension SessionDemo {
    fileprivate func generateClientKeys(clientId: String) -> (String?, String?, String?) {
        guard let keyGeneratorEC: TSKeyGen = TSKeyGen(algorithm: .EC) else {
            print("💥 Error occurred while initializing object keyGeneratorEC", #function)
            return (nil, nil, nil)
        }
        let privateKeyEC: Data = keyGeneratorEC.privateKey as Data
        let publicKeyEC: Data = keyGeneratorEC.publicKey as Data

        let privateKeyECString = privateKeyEC.base64EncodedString(options: .lineLength64Characters)
        let publicKeyECString = publicKeyEC.base64EncodedString(options: .lineLength64Characters)

        let randomizedClientId = "\(clientId)_#\(arc4random_uniform(100000))"
        
        return (privateKeyECString, publicKeyECString, randomizedClientId)
    }
}


// Networking
extension SessionDemo {
    fileprivate func postDiscoveryMessageFrom(clientId: String, clientPublicKey:String,
                                         completion: @escaping (_ data: Data?, _ error: Error?) -> Void) {
        
        let baseURL: String = Constants.BaseURL.rawValue
        let path: String = baseURL + "connect_request"

        let escapedClientId: String = clientId.addingPercentEncoding(withAllowedCharacters: CharacterSet.alphanumerics)!
        let escapedPublicKey: String = clientPublicKey.addingPercentEncoding(withAllowedCharacters: CharacterSet.alphanumerics)!
        let params: String = "\("client_name=")\(escapedClientId)&\("public_key=")\(escapedPublicKey)"
        
        postRequestTo(path, body: params, completion: completion)
    }


    fileprivate func postEncryptedMessage(message: Data, clientId: String,
                                          completion: @escaping (_ data: Data?, _ error: Error?) -> Void) {

        let baseURL: String = Constants.BaseURL.rawValue
        let path: String = baseURL + "message"
        
        let escapedBase64URLEncodedMessage: String = message.base64EncodedString(options: .endLineWithLineFeed)
            .addingPercentEncoding(withAllowedCharacters: CharacterSet.alphanumerics)!
        let escapedClientId: String = clientId.addingPercentEncoding(withAllowedCharacters: CharacterSet.alphanumerics)!
        
        let base64Body: String = "\("client_name=")\(escapedClientId)&\("message=")\(escapedBase64URLEncodedMessage)"

        postRequestTo(path, body: base64Body, completion: completion)
    }
    
    
    fileprivate func postRequestTo(_ path: String, body: String, completion: @escaping (_ data: Data?, _ error: Error?) -> Void) {
        let url: URL = URL(string: path)!
        let config: URLSessionConfiguration = URLSessionConfiguration.default
        let session: URLSession = URLSession(configuration: config)
        
        let request: NSMutableURLRequest = NSMutableURLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-type")
        
        let bodyData: Data = body.data(using: .utf8)!

        print("--->\n\(body)\n")
        
        let uploadTask: URLSessionDataTask = session.uploadTask(with: request as URLRequest, from: bodyData) {
                (data: Data?, response: URLResponse?, error: Error?) -> Void in
                
                
                if error != nil || data == nil {
                    print("😭 Oops, response:\n\(response as Optional)\n error:\n\(error as Optional)\n")
                    completion(nil, error)
                    return
                }
                
                
                var resultData = data!
                
                // what if data is base64 url encoded string? need to decode it first
                let dataString: String = String(data: resultData, encoding: .utf8)!.removingPercentEncoding!
                if let base64Data = Data(base64Encoded: dataString, options: .ignoreUnknownCharacters) {
                    resultData = base64Data
                }
                
                print("<---\n\(dataString)\n")

                if let response = response as? HTTPURLResponse, response.statusCode != 200 {
                    print("😭 Oops, response:\n\(response as Optional)\n error:\n\(error as Optional)\n")
                    completion(nil, error)
                    return
                }
                
                completion(resultData, nil)
        }
        
        uploadTask.resume()
    }
}
