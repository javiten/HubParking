import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Link(destination: URL(string: "tel:+13059679756")!) {
                        HStack {
                            Image(systemName: "phone.fill")
                                .foregroundColor(.accentColor)
                            Text("Contact Support")
                            Spacer()
                            Text("+1 (305) 967-9756")
                                .foregroundColor(.secondary)
                        }
                    }
                } footer: {
                    Text("Our support team is available 24/7")
                }
            }
            .navigationTitle("Help")
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