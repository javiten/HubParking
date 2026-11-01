import SwiftUI

struct NotificationsView: View {
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var showPermissionAlert = false
    @State private var showSettingsAlert = false
    
    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: notificationManager.isNotificationsEnabled ? "bell.badge.fill" : "bell.slash")
                        .foregroundColor(notificationManager.isNotificationsEnabled ? .green : .red)
                        .imageScale(.large)
                    
                    VStack(alignment: .leading) {
                        Text(notificationManager.isNotificationsEnabled ? "Notifications Enabled" : "Notifications Disabled")
                            .foregroundColor(notificationManager.isNotificationsEnabled ? .green : .red)
                            .fontWeight(.medium)
                        
                        if !notificationManager.isNotificationsEnabled {
                            Button("Enable Notifications") {
                                notificationManager.requestPermission()
                            }
                            .foregroundColor(.blue)
                            .padding(.top, 4)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            
            if notificationManager.isNotificationsEnabled {
                Section("Test Notifications") {
                    Button {
                        notificationManager.scheduleTestNotification(delay: 0)
                    } label: {
                        HStack {
                            Image(systemName: "bell.fill")
                            Text("Instant Test")
                        }
                    }
                    .foregroundColor(.blue)
                    
                    Button {
                        notificationManager.scheduleTestNotification(delay: 5)
                    } label: {
                        HStack {
                            Image(systemName: "clock.fill")
                            Text("5 Second Test")
                        }
                    }
                    .foregroundColor(.blue)
                    
                    Button {
                        notificationManager.scheduleTestNotification(delay: 10)
                    } label: {
                        HStack {
                            Image(systemName: "clock.fill")
                            Text("10 Second Test")
                        }
                    }
                    .foregroundColor(.blue)
                }
                
                Section {
                    Button(role: .destructive) {
                        notificationManager.removeAllPendingNotifications()
                    } label: {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("Clear All Notifications")
                        }
                    }
                }
            }
        }
        .navigationTitle("Notifications")
        .onAppear {
            notificationManager.checkNotificationStatus()
        }
        .alert("Enable Notifications", isPresented: $showSettingsAlert) {
            Button("Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable notifications in Settings to receive updates about parked vehicles.")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowNotificationSettingsAlert"))) { _ in
            showSettingsAlert = true
        }
    }
} 