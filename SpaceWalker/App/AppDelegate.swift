//
//  AppDelegate.swift
//  SpaceWalker
//
//  Created by andev on 9/27/25.
//

import UIKit
import FirebaseCore

@main
class AppDelegate: UIResponder, UIApplicationDelegate {



    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        RealmStorageConfigurator.configureDefaultRealmForBackup()
        
        FirebaseApp.configure()
        
        // Override point for customization after application launch.
        // Apply accent color only to Navigation Bar and Tab Bar
        if let accent = UIColor(named: "AccentColor_066985") {
            // Bar button items and interactive elements on Navigation Bar
            UINavigationBar.appearance().tintColor = accent
            // Selected item color and interactive elements on Tab Bar
            UITabBar.appearance().tintColor = accent
        }
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }


}
