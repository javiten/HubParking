import SwiftUI

struct ParkedVehiclesView: View {
    @EnvironmentObject private var viewModel: ParkedVehiclesViewModel
    @State private var showPickupConfirmation = false
    @State private var vehicleToPickup: ParkedVehicle?
    @State private var expandedAirports: Set<String> = []  // Track expanded airports
    @AppStorage("currentUser") private var currentUser: String = ""
    
    var groupedVehicles: [String: [ParkedVehicle]] {
        Dictionary(grouping: viewModel.parkedVehicles) { $0.airportName }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(Array(groupedVehicles.keys.sorted()), id: \.self) { airportName in
                        VStack(spacing: 0) {
                            // Airport Header
                            Button(action: {
                                toggleAirport(airportName)
                            }) {
                                HStack {
                                    Text(airportName)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text("\(groupedVehicles[airportName]?.count ?? 0)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Image(systemName: expandedAirports.contains(airportName) ? "chevron.up" : "chevron.down")
                                        .foregroundColor(.gray)
                                        .animation(.easeInOut, value: expandedAirports)
                                }
                                .padding()
                                .background(Color(.systemBackground))
                            }
                            
                            // Vehicle Cards
                            if expandedAirports.contains(airportName) {
                                ForEach(groupedVehicles[airportName] ?? []) { vehicle in
                                    ParkedVehicleCard(parkedVehicle: vehicle, isHistoryView: false)
                                        .transition(.opacity.combined(with: .slide))
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                vehicleToPickup = vehicle
                                                showPickupConfirmation = true
                                            } label: {
                                                Label("Pick Up", systemImage: "car.fill")
                                            }
                                        }
                                }
                            }
                        }
                        .background(Color(.systemGroupedBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 4)
            }
            .refreshable {
                print("Refreshing data...")
                await viewModel.loadVehicles()
                print("Refresh complete. Found \(viewModel.parkedVehicles.count) vehicles")
            }
            .overlay {
                if viewModel.parkedVehicles.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView {
                        Label("No Vehicles", systemImage: "car.fill")
                    } description: {
                        Text("Add a vehicle to get started")
                    }
                }
                
                if viewModel.isLoading {
                    ProgressView()
                }
            }
            .navigationTitle("Parked Vehicles")
            .task {
                print("Initial load...")
                await viewModel.loadVehicles()
            }
        }
        .alert("Confirm Pickup", isPresented: $showPickupConfirmation) {
            Button("Cancel", role: .cancel) {
                vehicleToPickup = nil
            }
            Button("Pick Up", role: .destructive) {
                if let vehicle = vehicleToPickup {
                        Task {
                        await viewModel.pickupVehicle(vehicle, pickedUpBy: currentUser)
                    }
                }
                vehicleToPickup = nil
            }
        } message: {
            if let vehicle = vehicleToPickup {
                Text("Are you sure you want to pick up \(vehicle.vehicle.description)?")
            }
        }
    }
    
    private func toggleAirport(_ airport: String) {
        withAnimation {
            if expandedAirports.contains(airport) {
                expandedAirports.remove(airport)
            } else {
                expandedAirports.insert(airport)
            }
        }
    }
}

#Preview {
    ParkedVehiclesView()
} 