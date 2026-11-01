import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var userManager: UserManager
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var showDiceRoll = false
    @State private var showSnake = false
    @State private var showVehicleDBTest = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Dark Mode", isOn: $themeManager.isDarkMode)
                } header: {
                    Text("General")
                }
                
                Section {
                    HStack {
                        Text("Logged in as")
                        Spacer()
                        if let user = userManager.currentUser {
                            Text(user.name)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Not logged in")
                                .foregroundColor(.red)
                        }
                    }
                    
                    Button(role: .destructive) {
                        withAnimation {
                            userManager.signOut()
                        }
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } header: {
                    Text("Account")
                }
                
                Section("Games") {
                    Button { showDiceRoll = true } label: { Label("Roll Two Dice", systemImage: "dice.fill") }
                    Button { showSnake = true } label: { Label("Snake", systemImage: "gamecontroller.fill") }
                }
                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("About HUB Parking", systemImage: "info.circle")
                    }
                    
                    NavigationLink {
                        HelpView()
                    } label: {
                        Label("Help", systemImage: "questionmark.circle")
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $showSnake) { SnakeView() }
            .sheet(isPresented: $showDiceRoll) {
                DiceRollView()
            }
        }
        .onAppear {
            print("Current user: \(String(describing: userManager.currentUser))")
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(UserManager())
        .environmentObject(ThemeManager())
} 