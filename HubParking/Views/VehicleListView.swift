import SwiftUI

struct VehicleListView: View {
    @EnvironmentObject private var viewModel: ParkedVehiclesViewModel
    @State private var search = ""
    @State private var loading = false
    @State private var deleting = false
    @State private var showAdd = false
    @State private var editing: Vehicle?
    @State private var pendingDelete: Vehicle?
    @State private var errorMessage: String?

    private var matches: [Vehicle] {
        viewModel.vehicles.filter { search.isEmpty || $0.description.localizedCaseInsensitiveContains(search) }
            .sorted { $0.description.localizedStandardCompare($1.description) == .orderedAscending }
    }

    var body: some View {
        List {
            Section {
                ForEach(matches) { vehicle in
                    Button { editing = vehicle } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "car.fill").foregroundStyle(.blue)
                                .frame(width: 40, height: 40)
                                .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(vehicle.make) \(vehicle.model)")
                                    .font(.headline).foregroundStyle(.primary)
                                Text(vehicle.plate).font(.subheadline.monospaced()).foregroundStyle(.secondary)
                                if let tracker = vehicle.airTag { Text("AirTag: \(tracker.name)").font(.caption).foregroundStyle(.secondary) }
                            }
                            Spacer()
                            Image(systemName: "pencil").foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .swipeActions(allowsFullSwipe: false) {
                        Button(role: .destructive) { pendingDelete = vehicle } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .contextMenu {
                        Button { editing = vehicle } label: { Label("Edit", systemImage: "pencil") }
                        Button(role: .destructive) { pendingDelete = vehicle } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            } footer: {
                Text("Tap a vehicle to edit it. Swipe left to delete. Removing a vehicle from the fleet keeps its parking and pickup history.")
            }
        }
        .disabled(deleting)
        .toolbar { ToolbarItem(placement: .topBarLeading) { FloatingVehicleSearch(text: $search) } }
        .toolbar { ToolbarItem(placement: .topBarTrailing) { ParkingSettingsButton() } }
        .navigationTitle("Vehicles")
        .overlay {
            if loading && viewModel.vehicles.isEmpty { ProgressView("Loading vehicles…") }
            else if matches.isEmpty {
                ContentUnavailableView(search.isEmpty ? "No Vehicles" : "No Matches", systemImage: "car.2",
                    description: Text(search.isEmpty ? "Tap + to add your first vehicle." : "Try a different search."))
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add Vehicle")
            }
        }
        .task { await reload() }
        .refreshable { await reload() }
        .sheet(isPresented: $showAdd) { VehicleEditorView(vehicle: nil).environmentObject(viewModel) }
        .sheet(item: $editing) { VehicleEditorView(vehicle: $0).environmentObject(viewModel) }
        .confirmationDialog("Delete this vehicle?", isPresented: Binding(
            get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }
        ), titleVisibility: .visible) {
            if let vehicle = pendingDelete {
                Button("Delete \(vehicle.plate)", role: .destructive) { Task { await delete(vehicle) } }
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: { Text("This removes the vehicle from the active fleet. Existing parking and history records are kept.") }
        .alert("Could Not Complete Action", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) { Button("OK") { errorMessage = nil } } message: { Text(errorMessage ?? "") }
    }

    @MainActor private func reload() async {
        loading = true
        defer { loading = false }
        do { viewModel.vehicles = try await SupabaseService.shared.fetchVehicles() }
        catch { errorMessage = error.localizedDescription }
    }

    @MainActor private func delete(_ vehicle: Vehicle) async {
        deleting = true
        pendingDelete = nil
        defer { deleting = false }
        guard !viewModel.offlineQueue.contains(where: { operation in
            switch operation {
            case .park(let parked), .update(let parked): return parked.vehicle.id == vehicle.id
            case .pickup: return false
            }
        }) else {
            errorMessage = "This vehicle has pending offline changes. Sync them before deleting it."
            return
        }
        do {
            try await SupabaseService.shared.deleteVehicle(vehicle.id)
            viewModel.vehicles.removeAll { $0.id == vehicle.id }
        } catch { errorMessage = error.localizedDescription }
    }
}

struct VehicleEditorView: View {
    let vehicle: Vehicle?
    @EnvironmentObject private var viewModel: ParkedVehiclesViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var make: String
    @State private var model: String
    @State private var plate: String
    @State private var tracker: String
    @State private var saving = false
    @State private var errorMessage: String?
    @State private var newID = UUID()

    init(vehicle: Vehicle?) {
        self.vehicle = vehicle
        _make = State(initialValue: vehicle?.make ?? "")
        _model = State(initialValue: vehicle?.model ?? "")
        _plate = State(initialValue: vehicle?.plate ?? "")
        _tracker = State(initialValue: vehicle?.airTag?.name ?? "")
    }

    private var valid: Bool { [make, model, plate].allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }

    var body: some View {
        NavigationStack {
            Form {
                Section("Vehicle") {
                    TextField("Make", text: $make)
                    TextField("Model", text: $model)
                    TextField("License plate", text: $plate).textInputAutocapitalization(.characters)
                }
                Section {
                    TextField("AirTag name (optional)", text: $tracker)
                } header: { Text("Tracker") } footer: { Text("Leave blank to remove the AirTag assignment.") }
                if saving { ProgressView("Saving vehicle…") }
            }
            .autocorrectionDisabled()
            .disabled(saving)
            .navigationTitle(vehicle == nil ? "Add Vehicle" : "Edit Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(saving) }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { await save() } }.disabled(!valid || saving) }
            }
            .interactiveDismissDisabled(saving)
            .alert("Could Not Save Vehicle", isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) { Button("OK") { errorMessage = nil } } message: { Text(errorMessage ?? "") }
        }
    }

    @MainActor private func save() async {
        saving = true
        defer { saving = false }
        let trackerName = tracker.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = Vehicle(id: vehicle?.id ?? newID,
            make: make.trimmingCharacters(in: .whitespacesAndNewlines),
            model: model.trimmingCharacters(in: .whitespacesAndNewlines),
            plate: plate.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
            airTag: trackerName.isEmpty ? nil : TrackerDevice(name: trackerName))
        do {
            let saved = try await SupabaseService.shared.persistVehicle(candidate, isNew: vehicle == nil)
            if let index = viewModel.vehicles.firstIndex(where: { $0.id == saved.id }) {
                viewModel.vehicles[index] = saved
            } else { viewModel.vehicles.append(saved) }
            // Refresh joined vehicle details on the home screen as well.
            await viewModel.loadVehicles(force: true)
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
}
