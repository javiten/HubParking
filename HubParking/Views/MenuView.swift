import SwiftUI

struct MenuView: View {
    var body: some View {
        NavigationView {
            List {
                MenuButton(title: "Add Vehicle Location", icon: "plus.circle.fill")
                MenuButton(title: "Pick up History", icon: "clock.fill")
                MenuButton(title: "Trends", icon: "chart.line.uptrend.xyaxis")
                MenuButton(title: "AirTag Location", icon: "location.circle.fill")
                MenuButton(title: "Help", icon: "questionmark.circle.fill")
                MenuButton(title: "About", icon: "info.circle.fill")
            }
            .navigationTitle("Menu")
        }
    }
}

struct MenuButton: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .imageScale(.large)
                .frame(width: 30)
            Text(title)
        }
        .padding(.vertical, 8)
    }
} 