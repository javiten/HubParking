import SwiftUI

struct AddParkedVehicleView: View {
    @State private var parkingSpot: String = ""
    @State private var notes: String = ""
    @FocusState private var focusedField: Field?
    
    var body: some View {
        ScrollView {
            VStack {
                // Your existing content
                TextField("Parking Spot", text: $parkingSpot)
                    .focused($focusedField, equals: .parkingSpot)
                
                TextField("Notes", text: $notes)
                    .focused($focusedField, equals: .notes)
                
                // Other content...
            }
            .padding()
        }
        .handleKeyboard()
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedField = nil
                }
            }
        }
    }
    
    private enum Field {
        case parkingSpot
        case notes
    }
} 