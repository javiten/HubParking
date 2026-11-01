import SwiftUI

struct AirTagAssignmentView: View {
    @EnvironmentObject private var viewModel: ParkedVehiclesViewModel
    @State private var search = ""
    @State private var editing: Vehicle?
    @State private var removing: Vehicle?
    @State private var showAdd = false
    @State private var errorMessage: String?
    @State private var busy = false
    private var assigned: [Vehicle] {
        viewModel.vehicles.filter { $0.airTag != nil && (search.isEmpty || "\($0.description) \($0.airTag?.name ?? "")".localizedCaseInsensitiveContains(search)) }
            .sorted { ($0.airTag?.name ?? "") < ($1.airTag?.name ?? "") }
    }
    var body: some View {
        List {
            Section {
                ForEach(assigned) { vehicle in
                    Button { editing = vehicle } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "airtag.fill").font(.title).foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(vehicle.airTag?.name ?? "").font(.headline).foregroundStyle(.primary)
                                Text(vehicle.description).font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "pencil").foregroundStyle(.secondary)
                        }.padding(.vertical, 6)
                    }
                    .swipeActions(allowsFullSwipe: false) {
                        Button(role: .destructive) { removing = vehicle } label: { Label("Unassign", systemImage: "trash") }
                    }
                }
            } footer: { Text("Tap to change an AirTag name. Swipe left to remove its assignment; the vehicle stays in your fleet.") }
        }
        .disabled(busy)
        .toolbar { ToolbarItem(placement: .topBarLeading) { FloatingVehicleSearch(text: $search) } }
        .toolbar { ToolbarItem(placement: .topBarTrailing) { ParkingSettingsButton() } }
        .navigationTitle("AirTags")
        .toolbar { ToolbarItem(placement: .primaryAction) { Button { showAdd = true } label: { Image(systemName: "plus") }.accessibilityLabel("Add AirTag assignment") } }
        .overlay { if assigned.isEmpty { ContentUnavailableView("No AirTags", systemImage: "airtag", description: Text("Tap + to assign an AirTag to a vehicle.")) } }
        .refreshable { await viewModel.loadVehicles(force: true) }
        .sheet(item: $editing) { TrackerEditor(vehicle: $0).environmentObject(viewModel) }
        .sheet(isPresented: $showAdd) { TrackerEditor(vehicle: nil).environmentObject(viewModel) }
        .confirmationDialog("Remove AirTag assignment?", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }), titleVisibility: .visible) {
            if let vehicle = removing {
                Button("Remove Assignment", role: .destructive) { Task { await remove(vehicle) } }
            }
        }
        .alert("Could Not Update AirTag", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }
    @MainActor private func remove(_ vehicle: Vehicle) async {
        busy = true; removing = nil
        defer { busy = false }
        do {
            let saved = try await SupabaseService.shared.updateVehicleTracker(vehicle, name: nil)
            if let index = viewModel.vehicles.firstIndex(where: { $0.id == saved.id }) { viewModel.vehicles[index] = saved }
            await viewModel.loadVehicles(force: true)
        } catch { errorMessage = error.localizedDescription }
    }
}

private struct TrackerEditor: View {
    let vehicle: Vehicle?
    @EnvironmentObject private var viewModel: ParkedVehiclesViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selected: UUID?
    @State private var name: String
    @State private var busy = false
    @State private var errorMessage: String?
    init(vehicle: Vehicle?) {
        self.vehicle = vehicle
        _selected = State(initialValue: vehicle?.id)
        _name = State(initialValue: vehicle?.airTag?.name ?? "")
    }
    private var candidates: [Vehicle] { viewModel.vehicles.filter { $0.airTag == nil || $0.id == vehicle?.id } }
    var body: some View {
        NavigationStack {
            Form {
                Picker("Vehicle", selection: $selected) {
                    Text("Select Vehicle").tag(nil as UUID?)
                    ForEach(candidates) { Text($0.description).tag(Optional($0.id)) }
                }.disabled(vehicle != nil)
                TextField("AirTag name", text: $name).autocorrectionDisabled()
                if busy { ProgressView() }
            }.disabled(busy)
            .navigationTitle(vehicle == nil ? "Assign AirTag" : "Edit AirTag")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(busy) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(busy || selected == nil || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .interactiveDismissDisabled(busy)
            .alert("Could Not Save", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }
    @MainActor private func save() async {
        guard let target = viewModel.vehicles.first(where: { $0.id == selected }) else { return }
        busy = true; defer { busy = false }
        do {
            let saved = try await SupabaseService.shared.updateVehicleTracker(target, name: name.trimmingCharacters(in: .whitespacesAndNewlines))
            if let index = viewModel.vehicles.firstIndex(where: { $0.id == saved.id }) { viewModel.vehicles[index] = saved }
            await viewModel.loadVehicles(force: true)
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
}
