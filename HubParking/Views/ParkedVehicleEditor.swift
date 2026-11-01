import SwiftUI

struct ParkedVehicleEditor: View {
    let vehicleID: UUID
    let initialVehicle: ParkedVehicle
    @EnvironmentObject private var viewModel: ParkedVehiclesViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var notes = ""
    @State private var images: [UIImage] = []
    @State private var showPicker = false
    @State private var busy = false
    @State private var errorMessage: String?
    @State private var pendingDeletion: String?
    @State private var removedPaths: Set<String> = []

    private var vehicle: ParkedVehicle {
        viewModel.parkedVehicles.first { $0.id == vehicleID } ?? initialVehicle
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label(vehicle.vehicle.description, systemImage: "car.fill")
                    Text("\((vehicle.garageName ?? "").replacingOccurrences(of: "IBIS", with: "Ibis")) · \(vehicle.parkingSpot ?? "")")
                        .foregroundStyle(.secondary)
                }
                Section("Notes") {
                    TextField("Parking notes…", text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                }
                Section {
                    ForEach(vehicle.photoPaths.filter { !removedPaths.contains($0) }, id: \.self) { path in
                        HStack {
                            AsyncImage(url: SupabaseService.shared.photoURL(path: path)) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Image(systemName: "photo").foregroundStyle(.secondary)
                            }
                            .frame(width: 72, height: 72).clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            Text("Parking photo").font(.subheadline)
                            Spacer()
                            Button(role: .destructive) { pendingDeletion = path } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Delete parking photo")
                        }
                    }
                    Button { showPicker = true } label: {
                        Label("Add Photos", systemImage: "photo.badge.plus")
                    }
                    if !images.isEmpty {
                        Text("\(images.count) new photos ready to upload")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("Discard New Photos", role: .destructive) { images = [] }
                    }
                } header: {
                    Text("Photos")
                } footer: {
                    Text("Photo deletions are applied immediately. New photos and notes are saved with Save.")
                }
                if busy { ProgressView("Saving changes…") }
            }
            .disabled(busy)
            .navigationTitle("Edit Parking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(busy)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }.disabled(busy)
                }
            }
            .onAppear { notes = vehicle.notes ?? "" }
            .sheet(isPresented: $showPicker) { MultiImagePicker(selectedImages: $images) }
            .confirmationDialog("Delete this photo permanently?", isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ), titleVisibility: .visible) {
                if let path = pendingDeletion {
                    Button("Delete Photo", role: .destructive) { Task { await deletePhoto(path) } }
                }
                Button("Cancel", role: .cancel) { pendingDeletion = nil }
            }
            .alert("Could Not Save Changes", isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
            .interactiveDismissDisabled(busy)
        }
    }

    @MainActor
    private func save() async {
        busy = true
        defer { busy = false }
        do {
            let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            try await viewModel.updateParkedVehicleNotes(vehicle, notes: trimmed.isEmpty ? nil : trimmed)
            if !images.isEmpty {
                try await viewModel.addPhotos(images, to: vehicle) { _, _ in }
                images = []
            }
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }

    @MainActor
    private func deletePhoto(_ path: String) async {
        busy = true
        pendingDeletion = nil
        defer { busy = false }
        do {
            try await SupabaseService.shared.removeVehiclePhoto(
                vehicleId: vehicleID, currentPhotoValue: vehicle.photoPath, pathToRemove: path)
            removedPaths.insert(path)
            // A forced reload is necessary even immediately after another edit.
            await viewModel.loadVehicles(force: true)
        } catch { errorMessage = error.localizedDescription }
    }
}
