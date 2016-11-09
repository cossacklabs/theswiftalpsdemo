//
//  AppDelegate.swift
//  SwiftAlpsSecDemo
//
//  Created by Anastasiia on 11/8/16.
//  Copyright © 2016 Anastasiia Vxtl. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        print(" ------------ running Cell Demo example -------------- ")
        CellDemo().runDemo()
        
//        print(" ------------ running Session Demo example ----------- ")
//        SessionDemo().runDemo()
        
        return true
    }


}

