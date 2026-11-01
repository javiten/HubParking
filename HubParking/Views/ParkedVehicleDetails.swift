import SwiftUI
import MapKit

struct ParkedVehicleDetails: View {
    let parkedVehicle: ParkedVehicle
    @Environment(\.dismiss) private var dismiss
    @State private var selectedView: String = "Info"
    
    var body: some View {
        NavigationStack {
            VStack {
                if parkedVehicle.photoPath != nil {
                    Picker("View", selection: $selectedView) {
                        Text("Info").tag("Info")
                        if parkedVehicle.photoPath != nil {
                            Text("Photo").tag("Photo")
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    
                    switch selectedView {
                    case "Photo":
                        if let photoPath = parkedVehicle.photoPath {
                            AsyncImage(url: SupabaseService.shared.photoURL(path: photoPath)) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                case .success(let image):
                                    image.resizable()
                                         .aspectRatio(contentMode: .fit)
                                case .failure:
                                    Image(systemName: "photo.circle")
                                        .foregroundColor(.gray)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        }
                    default:
                        List {
                            Section {
                                LabeledContent("Vehicle", value: parkedVehicle.vehicle.description)
                                LabeledContent("Airport", value: parkedVehicle.airportName)
                                LabeledContent("Garage", value: parkedVehicle.garageName ?? "Unknown")
                                LabeledContent("Spot", value: parkedVehicle.parkingSpot ?? "Unknown")
                                LabeledContent("Date Parked", value: parkedVehicle.dateParked.formatted(date: .abbreviated, time: .shortened))
                            } header: {
                                Text("Vehicle Information")
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Vehicle Details")
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