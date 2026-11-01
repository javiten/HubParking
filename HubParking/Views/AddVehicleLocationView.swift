import SwiftUI
import MapKit
import CoreLocation

struct AddVehicleLocationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var userManager: UserManager
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject var viewModel: ParkedVehiclesViewModel
    @Environment(\.selectedTabBinding) private var selectedTabBinding
    
    @State private var showVehiclePicker = false
    @State private var selectedVehicle: Vehicle?
    @State private var selectedAirport: Airport?
    @State private var selectedGarage: Garage?
    @State private var parkingSpot = ""
    @State private var selectedImage: UIImage?
    @State private var notes = ""
    @State private var showImagePicker = false
    
    // Demo airports and garages (keep these for now)
    static let airports = [
        Airport(name: "FLL Airport", garages: [
            Garage(name: "Hibiscus"),
            Garage(name: "Palm"),
            Garage(name: "Cypress")
        ]),
        Airport(name: "MIA Airport", garages: [
            Garage(name: "Dolphin"),
            Garage(name: "Flamingo"),
            Garage(name: "Ibis")
        ]),
        Airport(name: "OFFICE", garages: [Garage(name: "Office")])
    ]
    
    var availableGarages: [Garage] {
        selectedAirport?.garages ?? []
    }
    
    @State private var step = 0
    @State private var saving = false
    @State private var saveError: String?
    @State private var showDuplicateWarning = false
    @State private var existingParkingDescription = ""

    private var canContinue: Bool {
        step == 0 ? selectedVehicle != nil : (step == 1 ? selectedAirport != nil && selectedGarage != nil && !parkingSpot.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty : isFormValid)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("STEP \(step + 1) OF 3").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                            Text(["Choose your car", "Where are you parking?", "Add the details"][step])
                                .font(.largeTitle.bold())
                            HStack(spacing: 6) {
                                ForEach(0..<3) { index in
                                    Capsule().fill(index <= step ? Color.accentColor : Color.secondary.opacity(0.2)).frame(height: 4)
                                }
                            }
                            if let vehicle = selectedVehicle {
                                Label(vehicle.description, systemImage: "car.fill").font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 24)
                        VStack(alignment: .leading, spacing: 20) {
                            if step == 0 {
                                Text("Select a vehicle to get started.").foregroundStyle(.secondary)
                                Button { showVehiclePicker = true } label: {
                                    HStack(spacing: 14) {
                                        Image(systemName: "car.2.fill").font(.title)
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(selectedVehicle?.description ?? "Choose Vehicle").font(.headline)
                                            Text("Search by make, model or plate").font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                    }.padding(18).frame(maxWidth: .infinity, minHeight: 80)
                                }.buttonStyle(.bordered)
                            } else if step == 1 {
                                Text("Location").font(.headline)
                                HStack {
                                    ForEach(["MIA", "FLL", "OFFICE"], id: \.self) { code in
                                        Button {
                                            selectedAirport = Self.airports.first { $0.name.contains(code) }
                                            selectedGarage = selectedAirport?.garages.count == 1 ? selectedAirport?.garages.first : nil
                                        } label: {
                                            Text(code).font(.headline).frame(maxWidth: .infinity, minHeight: 44)
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(selectedAirport?.name.contains(code) == true ? .blue : .gray)
                                    }
                                }
                                if let airport = selectedAirport {
                                    Text("Garage").font(.headline)
                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 10) {
                                        ForEach(airport.garages) { garage in
                                            Button { selectedGarage = garage } label: {
                                                HStack {
                                                    Text(garage.name)
                                                    if selectedGarage?.id == garage.id { Image(systemName: "checkmark") }
                                                }.frame(maxWidth: .infinity, minHeight: 44)
                                            }.buttonStyle(.bordered).tint(selectedGarage?.id == garage.id ? .blue : .gray)
                                        }
                                    }
                                }
                                TextField("Row / parking spot", text: $parkingSpot)
                                    .textInputAutocapitalization(.characters).autocorrectionDisabled()
                                    .padding(16).background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                            } else {
                                Label("\(selectedAirport?.name ?? "") · \(selectedGarage?.name ?? "") · \(parkingSpot)", systemImage: "mappin.and.ellipse")
                                    .font(.headline)
                                if let image = selectedImage {
                                    Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 120).clipShape(RoundedRectangle(cornerRadius: 14))
                                }
                                HStack {
                                    Spacer()
                                    Button { showImagePicker = true } label: {
                                        Label(selectedImage == nil ? "Add Photo" : "Change Photo", systemImage: "camera.fill").frame(minHeight: 44)
                                    }.buttonStyle(.bordered)
                                }
                                TextField("Notes (optional)", text: $notes, axis: .vertical)
                                    .lineLimit(3...5).padding(16)
                                    .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                                Text("Photo and notes are optional. You can edit them later.").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(20)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
                    }
                    .padding(20)
                    .frame(minHeight: max(0, geometry.size.height), alignment: .bottom)
                }.scrollDismissesKeyboard(.interactively)
            }
            .background(Color(.systemGroupedBackground))
            .safeAreaInset(edge: .bottom, spacing: 0) {
                HStack(spacing: 16) {
                    Button {
                        hideKeyboard()
                        if step > 0 { step -= 1 } else { selectedTabBinding.wrappedValue = 0 }
                    } label: {
                        Label(step == 0 ? "Home" : "Back", systemImage: "chevron.left").frame(minHeight: 52)
                    }.buttonStyle(.bordered)
                    Spacer(minLength: 0)
                    Button {
                        hideKeyboard()
                        if step < 2 { withAnimation { step += 1 } } else { saveVehicle() }
                    } label: {
                        HStack {
                            if saving { ProgressView().tint(.white) }
                            Text(step < 2 ? "Continue" : "Park Vehicle").font(.headline)
                            Image(systemName: step < 2 ? "arrow.right" : "checkmark")
                        }.frame(minWidth: 150, minHeight: 52)
                    }.buttonStyle(.borderedProminent).disabled(!canContinue || saving)
                }
                .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 24)
                .background(Color(.systemGroupedBackground))
            }
            .disabled(saving)
            .navigationTitle("Park a Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { ParkingSettingsButton() }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { hideKeyboard() } }
            }
            .task { await viewModel.loadVehicles() }
            .sheet(isPresented: $showVehiclePicker) {
                VehicleSelectionView(vehicles: viewModel.vehicles, selection: $selectedVehicle)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showImagePicker) { ImagePicker(selectedImage: $selectedImage) }
            .alert("Vehicle Already Parked", isPresented: $showDuplicateWarning) {
                Button("Park Again") { saveVehicle(confirmDuplicate: true) }
                Button("Choose Another Vehicle") {
                    selectedVehicle = nil
                    step = 0
                    showVehiclePicker = true
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This vehicle is already parked at \(existingParkingDescription). Would you like to park it again or choose another vehicle? The existing parking card will be kept.")
            }
            .alert("Could Not Park Vehicle", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
                Button("OK") { saveError = nil }
            } message: { Text(saveError ?? "") }
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private var isFormValid: Bool {
        selectedVehicle != nil &&
        selectedAirport != nil &&
        selectedGarage != nil &&
        !parkingSpot.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func saveVehicle(confirmDuplicate: Bool = false) {
        guard let vehicle = selectedVehicle,
              let airport = selectedAirport,
              let garage = selectedGarage,
              let currentUser = userManager.currentUser else {
            return
        }
        
        saving = true
        Task { @MainActor in
            defer { saving = false }
            do {
                if !confirmDuplicate {
                    // Check current server data, including parking added on another phone.
                    let currentParking = try await SupabaseService.shared.fetchParkedVehicles()
                    viewModel.parkedVehicles = currentParking
                    let existing = currentParking.filter { $0.vehicle.id == vehicle.id }
                        .sorted { $0.dateParked > $1.dateParked }
                    if !existing.isEmpty {
                        existingParkingDescription = existing.map { record in
                            let garage = (record.garageName ?? record.airportName)
                                .replacingOccurrences(of: "IBIS", with: "Ibis")
                            return [garage, record.parkingSpot ?? ""].filter { !$0.isEmpty }.joined(separator: " ")
                        }.joined(separator: "; ")
                        showDuplicateWarning = true
                        return
                    }
                }
                try await viewModel.createParkedVehicle(
                    from: vehicle,
                    at: airport,
                    in: garage,
                    spot: parkingSpot.trimmingCharacters(in: .whitespacesAndNewlines),
                    photo: selectedImage,
                    notes: notes.isEmpty ? nil : notes,
                    addedBy: currentUser.name
                )
                
                // Reset form and switch to home tab
                selectedVehicle = nil
                selectedAirport = nil
                selectedGarage = nil
                parkingSpot = ""
                selectedImage = nil
                notes = ""
                step = 0
                selectedTabBinding.wrappedValue = 0
                
            } catch {
                saveError = error.localizedDescription
            }
        }
    }
}

// Location Picker View
struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationManager = LocationManager()
    @Binding var selectedLocation: CLLocationCoordinate2D?
    @State private var showLocationPermissionAlert = false
    @State private var showLocationServicesAlert = false
    @State private var cameraPosition = MapCameraPosition.userLocation(fallback: .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 26.0725, longitude: -80.1525),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )))
    
    var body: some View {
        NavigationStack {
            ZStack {
                Map(position: $cameraPosition) {
                    if let location = locationManager.location?.coordinate {
                        Marker("Current Location", coordinate: location)
                            .tint(.blue)
                    }
                }
                .mapStyle(.standard)
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                }
                .ignoresSafeArea()
                .scrollDisabled(true)
                .gesture(DragGesture().onChanged { _ in })
                .allowsHitTesting(false)
                
                // Loading indicator when getting location
                if locationManager.location == nil {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(1.5)
                }
                
                // Location button overlay
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: requestLocation) {
                            Image(systemName: "location.circle.fill")
                                .font(.system(size: 44))
                                .foregroundColor(.accentColor)
                                .background(Circle().fill(Color(.systemBackground)))
                                .shadow(radius: 3)
                        }
                        .padding()
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Current Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        selectedLocation = locationManager.location?.coordinate
                        dismiss()
                    }
                    .disabled(locationManager.location == nil)
                }
            }
            .alert("Location Access Required", isPresented: $showLocationPermissionAlert) {
                Button("Open Settings", role: .none) {
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Please enable location access in Settings to use this feature.")
            }
            .alert("Location Services Disabled", isPresented: $showLocationServicesAlert) {
                Button("Open Settings", role: .none) {
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Please enable Location Services in your device settings to use this feature.")
            }
            .onAppear {
                checkLocationServices()
            }
        }
    }
    
    func checkLocationServices() {
        if CLLocationManager.locationServicesEnabled() {
            requestLocation()
        } else {
            showLocationServicesAlert = true
        }
    }
    
    func requestLocation() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            print("Requesting permission")
            locationManager.requestPermission()
        case .restricted, .denied:
            print("Showing permission alert")
            showLocationPermissionAlert = true
        case .authorizedWhenInUse, .authorizedAlways:
            print("Getting location")
            locationManager.startUpdating()
            if let location = locationManager.location?.coordinate {
                withAnimation {
                    cameraPosition = .region(MKCoordinateRegion(
                        center: location,
                        span: MKCoordinateSpan(latitudeDelta: 0.001, longitudeDelta: 0.001)
                    ))
                }
            }
        @unknown default:
            break
        }
    }
}

#Preview {
    AddVehicleLocationView(viewModel: ParkedVehiclesViewModel())
        .environmentObject(UserManager())
        .environmentObject(ThemeManager())
} 

struct VehicleSelectionView: View {
    let vehicles: [Vehicle]
    @Binding var selection: Vehicle?
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    // A snapshot keeps background refreshes from rebuilding an open selection list.
    @State private var snapshot: [Vehicle] = []

    private var matches: [Vehicle] {
        snapshot.filter { query.isEmpty || $0.description.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            List(matches) { vehicle in
                Button {
                    selection = vehicle
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(vehicle.make) \(vehicle.model)").foregroundStyle(.primary)
                            Text(vehicle.plate).font(.subheadline.monospaced()).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if selection?.id == vehicle.id {
                            Image(systemName: "checkmark.circle.fill")
                        }
                    }
                    .padding(.vertical, 5)
                }
            }
            .toolbar { ToolbarItem(placement: .topBarLeading) { FloatingVehicleSearch(text: $query) } }
            .navigationTitle("Select Vehicle")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .onAppear { if snapshot.isEmpty { snapshot = vehicles } }
        }
    }
}
