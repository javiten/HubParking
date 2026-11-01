//
//  HubParkingApp.swift
//  HubParking
//
//  Created by Jav on 2/9/25.
//

import SwiftUI
import UserNotifications
import UIKit

@main
struct HubParkingApp: App {
    @StateObject private var userManager = UserManager()
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var viewModel = ParkedVehiclesViewModel()
    
    var body: some Scene {
        WindowGroup {
            if userManager.isAuthenticated {
                ContentView()
                    .environmentObject(userManager)
                    .environmentObject(themeManager)
                    .environmentObject(viewModel)
            } else {
                LoginView()
                    .environmentObject(userManager)
                    .environmentObject(themeManager)
            }
        }
    }
}
