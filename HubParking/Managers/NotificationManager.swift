import Foundation
import UserNotifications
import UIKit

class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    @Published var isNotificationsEnabled = false
    
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        checkNotificationStatus()
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    func requestPermission() {
        print("🔔 Requesting notification permissions...")
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound, .provisional]) { granted, error in
            DispatchQueue.main.async {
                self.isNotificationsEnabled = granted
                if granted {
                    print("✅ Notification permission granted")
                    // Register for remote notifications on the main thread
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                    self.checkNotificationStatus()
                } else {
                    print("❌ Notification permission denied")
                    if let error = error {
                        print("Error: \(error.localizedDescription)")
                    }
                    // Show alert to guide user to settings
                    self.showSettingsAlert()
                }
            }
        }
    }
    
    func checkNotificationStatus() {
        print("🔍 Checking notification status...")
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isNotificationsEnabled = settings.authorizationStatus == .authorized
                print("📱 Authorization Status: \(settings.authorizationStatus.rawValue)")
                print("📱 Alert Setting: \(settings.alertSetting.rawValue)")
                print("📱 Sound Setting: \(settings.soundSetting.rawValue)")
                print("📱 Badge Setting: \(settings.badgeSetting.rawValue)")
                print("📱 Notification Center Setting: \(settings.notificationCenterSetting.rawValue)")
                print("📱 Lock Screen Setting: \(settings.lockScreenSetting.rawValue)")
                print("📱 Critical Alert Setting: \(settings.criticalAlertSetting.rawValue)")
                
                if settings.authorizationStatus == .denied {
                    print("⚠️ Notifications are denied in settings")
                }
            }
        }
    }
    
    private func showSettingsAlert() {
        // Note: You'll need to implement this in your UI layer
        print("⚠️ Should show settings alert to user")
        NotificationCenter.default.post(name: NSNotification.Name("ShowNotificationSettingsAlert"), object: nil)
    }
    
    func scheduleTestNotification(delay: TimeInterval) {
        guard isNotificationsEnabled else {
            print("⚠️ Notifications are not enabled")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "HUB Parking Test"
        content.body = delay == 0 ? "This is an instant test notification" : "This is a test notification after \(Int(delay)) seconds"
        content.sound = .default
        
        let trigger = delay > 0 ? UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false) : nil
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error scheduling test notification: \(error.localizedDescription)")
            } else {
                print("✅ Test notification scheduled for \(delay == 0 ? "instant delivery" : "\(delay) seconds from now")")
            }
        }
    }
    
    func scheduleParkedNotification(vehicle: ParkedVehicle) {
        guard isNotificationsEnabled else {
            print("⚠️ Notifications are not enabled - skipping parked notification")
            return
        }
        
        print("🔔 Preparing parked notification for \(vehicle.vehicle.make) \(vehicle.vehicle.model)")
        
        let content = UNMutableNotificationContent()
        content.title = "Vehicle Parked"
        content.body = "\(vehicle.vehicle.make) \(vehicle.vehicle.model) was parked at \(vehicle.airportName)"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "parked-\(vehicle.id)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error scheduling parked notification: \(error.localizedDescription)")
            } else {
                print("✅ Parked notification scheduled for \(vehicle.vehicle.make) \(vehicle.vehicle.model)")
            }
        }
        
        // Schedule 7-day reminder
        let sevenDayContent = UNMutableNotificationContent()
        sevenDayContent.title = "Vehicle Parking Alert"
        sevenDayContent.body = "\(vehicle.vehicle.make) \(vehicle.vehicle.model) has been parked for 7 days"
        sevenDayContent.sound = .default
        
        let sevenDayTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 7 * 24 * 60 * 60, repeats: false)
        let sevenDayRequest = UNNotificationRequest(
            identifier: "sevenDay-\(vehicle.id)",
            content: sevenDayContent,
            trigger: sevenDayTrigger
        )
        
        UNUserNotificationCenter.current().add(sevenDayRequest) { error in
            if let error = error {
                print("❌ Error scheduling 7-day reminder: \(error.localizedDescription)")
            } else {
                print("✅ 7-day reminder scheduled for \(vehicle.vehicle.make) \(vehicle.vehicle.model)")
            }
        }
    }
    
    func schedulePickupNotification(vehicle: ParkedVehicle) {
        guard isNotificationsEnabled else {
            print("⚠️ Notifications are not enabled - skipping pickup notification")
            return
        }
        
        print("🔔 Preparing pickup notification for \(vehicle.vehicle.make) \(vehicle.vehicle.model)")
        
        let content = UNMutableNotificationContent()
        content.title = "Vehicle Picked Up"
        content.body = "\(vehicle.vehicle.make) \(vehicle.vehicle.model) was picked up from \(vehicle.airportName)"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "pickup-\(vehicle.id)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error scheduling pickup notification: \(error.localizedDescription)")
            } else {
                print("✅ Pickup notification scheduled for \(vehicle.vehicle.make) \(vehicle.vehicle.model)")
            }
        }
        
        // Remove any pending 7-day reminders for this vehicle
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["sevenDay-\(vehicle.id)"])
    }
    
    func removeAllPendingNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        print("🗑️ All pending notifications removed")
    }
} 