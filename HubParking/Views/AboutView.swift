import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 20) {
                        Image("hub-logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 180, height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .accessibilityLabel("Hub Car Share")
                        
                        Text("HUB Parking App")
                            .font(.title2)
                            .bold()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                    .listRowBackground(Color.clear)
                }
                
                Section("Contact Support") {
                    Link(destination: URL(string: "tel:+13059679756")!) {
                        Label("+1 (305) 967-9756", systemImage: "phone.fill")
                    }
                }

                Section("Credits") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Javier Marzano")
                            .font(.headline)
                        Text("Owner & CEO")
                            .font(.subheadline)
                        Text("Hub Services Corporation")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
} 