import SwiftUI
import MapKit

struct ParkedVehicleCard: View {
    let parkedVehicle: ParkedVehicle
    var showUndoButton: Bool = false
    @EnvironmentObject private var viewModel: ParkedVehiclesViewModel
    @State private var showPhotoModal = false
    @State private var showEditor = false
    @Environment(\.dismiss) private var dismiss
    @State private var isRestoring = false
    @State private var restoreError: String?
    @State private var vehicleImage: UIImage?
    @State private var isLoadingImage = false
    @State private var imageLoadTask: Task<Void, Never>?
    let isHistoryView: Bool
    @State private var showEditNotes = false
    @State private var editedNotes: String = ""
    @State private var isSavingNotes = false
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var isSavingPhoto = false
    @State private var isDeletingPhoto = false
    @State private var uploadProgress: Double = 0.0
    @State private var galleryImages: [String: UIImage] = [:]
    @State private var galleryErrors: Set<String> = []
    @State private var selectedImagesForUpload: [UIImage] = []
    @State private var photoError: String?
    @State private var lastPhotoPathTried: String?
    
    private var hasImage: Bool {
        if let currentVehicle = viewModel.parkedVehicles.first(where: { $0.id == parkedVehicle.id }) {
            return !currentVehicle.photoPaths.isEmpty
        }
        return !parkedVehicle.photoPaths.isEmpty
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !isHistoryView {
                HStack {
                    Label("Parked", systemImage: "parkingsign.circle.fill")
                        .font(.caption.weight(.semibold)).foregroundStyle(.blue)
                    Spacer()
                    Button { showEditor = true } label: {
                        Label("Edit", systemImage: "square.and.pencil")
                    }
                    .buttonStyle(.bordered)
                }
            }
            // Primary Info: Make Model + Plate
            Text("\(parkedVehicle.vehicle.make) \(parkedVehicle.vehicle.model) \(parkedVehicle.vehicle.plate)")
                .font(.system(size: 19, weight: .semibold))
            
            // Location
            Text("\((parkedVehicle.garageName ?? "Unknown").replacingOccurrences(of: "IBIS", with: "Ibis")) \(parkedVehicle.parkingSpot ?? "")")
                .font(.system(size: 15))
                .foregroundColor(.blue)
            
            if let notes = parkedVehicle.notes, !notes.isEmpty {
                Text(notes).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
            }

            // Time and Added By
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.secondary)
                    .font(.system(size: 13))
                Text(parkedVehicle.dateParked.formatted(date: .numeric, time: .shortened))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if self.hasImage {
                    Button {
                        Task {
                            showPhotoModal = true
                            photoError = nil
                        }
                    } label: {
                        Image(systemName: "photo.circle.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 20))
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Image management buttons
            if !isHistoryView {
                if isDeletingPhoto {
                    HStack {
                        ProgressView("Deleting image...")
                        Spacer()
                    }
                } else if isSavingPhoto {
                    HStack {
                        ProgressView(value: uploadProgress)
                            .frame(maxWidth: .infinity)
                        Text("\(Int(uploadProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if !selectedImagesForUpload.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(selectedImagesForUpload.enumerated()), id: \.offset) { _, img in
                                    Image(uiImage: img)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 64, height: 64)
                                        .clipped()
                                        .cornerRadius(8)
                                }
                            }
                        }
                        HStack(spacing: 12) {
                            Button {
                                Task {
                                    isSavingPhoto = true
                                    defer { isSavingPhoto = false }
                                    do {
                                        try await viewModel.addPhotos(selectedImagesForUpload, to: parkedVehicle) { _, _ in }
                                        await MainActor.run {
                                            selectedImagesForUpload.removeAll()
                                        }
                                    } catch {
                                        print("[DEBUG] addPhotos error: \(error)")
                                    }
                                }
                            } label: {
                                Label("Upload \(selectedImagesForUpload.count)", systemImage: "icloud.and.arrow.up")
                            }
                            .buttonStyle(.borderedProminent)

                            Button(role: .cancel) {
                                selectedImagesForUpload.removeAll()
                            } label: {
                                Text("Cancel")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                } else if self.hasImage {
                    HStack(spacing: 12) {
                        Button {
                            Task {
                                // Present immediately; image will appear when set
                                showPhotoModal = true
                                photoError = nil
                                }
                        } label: {
                            Label("View Image", systemImage: "eye")
                                .font(.system(size: 15))
                        }
                        .buttonStyle(.bordered)
                        .tint(.green)
                        
                        Menu {
                            Button {
                                // Open multi picker
                                selectedImagesForUpload.removeAll()
                                showImagePicker = true
                            } label: {
                                Label("Change Image", systemImage: "photo.on.rectangle")
                            }
                            
                            Button(role: .destructive) {
                                Task {
                                    // Determine current path from freshest model (first photo in array)
                                    let currentVehicle = viewModel.parkedVehicles.first(where: { $0.id == parkedVehicle.id }) ?? parkedVehicle
                                    let currentPath = currentVehicle.photoPaths.first
                                    print("[DEBUG] Delete Image tapped. Current path: \(currentPath ?? "nil")")
                                    guard let existingPath = currentPath else { return }
                                    isDeletingPhoto = true
                                    do {
                                        // Delete from storage and update DB reference
                                        try await SupabaseService.shared.removeVehiclePhoto(vehicleId: parkedVehicle.id, currentPhotoValue: currentVehicle.photoPath, pathToRemove: existingPath)
                                        await viewModel.loadVehicles()
                                        await MainActor.run {
                                            vehicleImage = nil
                                            showPhotoModal = false
                                        }
                                    } catch {
                                        print("[DEBUG] Delete Image flow failed: \(error)")
                                    }
                                    isDeletingPhoto = false
                                }
                            } label: {
                                Label("Delete Image", systemImage: "trash")
                            }
                        } label: {
                            Label("Edit Image", systemImage: "pencil")
                                .font(.system(size: 15))
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                    }
                    .padding(.top, 4)
                } else {
                    Button {
                        selectedImagesForUpload.removeAll()
                        showImagePicker = true
                    } label: {
                        Label("Add Image", systemImage: "camera")
                            .font(.system(size: 15))
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                    .padding(.top, 4)
                }
            }
            
            if showUndoButton {
                Button {
                    guard !isRestoring else { return }
                    Task { @MainActor in
                        isRestoring = true
                        defer { isRestoring = false }
                        do {
                            try await viewModel.undoPickup(parkedVehicle)
                            dismiss()
                        } catch { restoreError = error.localizedDescription }
                    }
                } label: {
                    Label(isRestoring ? "Restoring…" : "Return to Parking", systemImage: "arrow.uturn.left")
                        .font(.system(size: 15))
                }
                .buttonStyle(.bordered)
                .tint(.blue)
                .disabled(isRestoring)
                .padding(.top, 4)
            }
        }
        .alert("Could Not Restore Parking", isPresented: Binding(get: { restoreError != nil }, set: { if !$0 { restoreError = nil } })) {
            Button("OK") { restoreError = nil }
        } message: { Text(restoreError ?? "") }
        .interactiveDismissDisabled(isRestoring)
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .sheet(isPresented: $showEditor) {
            ParkedVehicleEditor(vehicleID: parkedVehicle.id, initialVehicle: parkedVehicle)
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $showPhotoModal) {
            ParkingPhotoGallery(paths: (viewModel.parkedVehicles.first(where: { $0.id == parkedVehicle.id }) ?? parkedVehicle).photoPaths)
        }
        .onChange(of: showPhotoModal) { oldValue, newValue in
            if !newValue {
                // Clear the image when closing
                vehicleImage = nil
            }
        }
        .sheet(isPresented: $showEditNotes) {
            NavigationView {
                VStack {
                    NotesInputView(text: $editedNotes)
                        .padding()
                    Spacer()
                }
                .navigationTitle(parkedVehicle.notes?.isEmpty == false ? "Edit Notes" : "Add Notes")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            Task {
                                await saveNotes()
                            }
                        }
                        .disabled(isSavingNotes)
                    }
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            showEditNotes = false
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            MultiImagePicker(selectedImages: $selectedImagesForUpload)
        }
        .onAppear {
            #if DEBUG
            let debugPhotoPath = parkedVehicle.photoPath ?? "nil"
            print("[DEBUG] photoPath for \(parkedVehicle.vehicle.plate): '\(debugPhotoPath)', hasImage: \(self.hasImage)")
            #endif
        }
    }
    
    private func loadPhoto() async {
        isLoadingImage = true
        defer { isLoadingImage = false }
        
        // Always fetch the freshest value from the view model
        photoError = nil
        let current = viewModel.parkedVehicles.first(where: { $0.id == parkedVehicle.id }) ?? parkedVehicle
        let paths = current.photoPaths
        guard let rawPath = paths.first else {
            print("[DEBUG] loadPhoto: No photoPath available")
            await MainActor.run { photoError = "No photo available for this vehicle." }
            return
        }
        let photoPath = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !photoPath.isEmpty, photoPath.lowercased() != "nil" else {
            print("[DEBUG] loadPhoto: Empty photoPath")
            await MainActor.run { photoError = "No photo available for this vehicle." }
            return
        }
        lastPhotoPathTried = photoPath
        
        print("[DEBUG] loadPhoto: Attempting to download photo from path: \(photoPath)")
        
        do {
            let imageData = try await SupabaseService.shared.downloadPhoto(path: photoPath)
            if let image = UIImage(data: imageData) {
                await MainActor.run {
                    self.vehicleImage = image
                    print("[DEBUG] loadPhoto: Successfully loaded image with size: \(image.size)")
                }
            } else {
                print("[DEBUG] loadPhoto: Failed to create UIImage from downloaded data")
                await MainActor.run { photoError = "Could not display the downloaded image." }
            }
        } catch {
            print("[DEBUG] loadPhoto: Error downloading photo: \(error)")
            let errorDescription = error.localizedDescription.lowercased()
            if errorDescription.contains("404") || errorDescription.contains("not found") || errorDescription.contains("object not found") {
                // Retry multiple times with backoff; do NOT delete
                let delays: [UInt64] = [400_000_000, 800_000_000, 1_600_000_000]
                for (idx, delay) in delays.enumerated() {
                    print("[DEBUG] loadPhoto: 404, retrying \(idx+1)/\(delays.count) after \(delay/1_000_000)ms...")
                    try? await Task.sleep(nanoseconds: delay)
                    do {
                        let retryData = try await SupabaseService.shared.downloadPhoto(path: photoPath)
                        if let image = UIImage(data: retryData) {
                            await MainActor.run { self.vehicleImage = image }
                            print("[DEBUG] loadPhoto: Loaded image after retry \(idx+1)")
                            return
                        } else {
                            print("[DEBUG] loadPhoto: Retry \(idx+1) returned invalid image data")
                        }
                    } catch {
                        print("[DEBUG] loadPhoto: Retry \(idx+1) failed: \(error)")
                    }
                }
                print("[DEBUG] loadPhoto: Still 404 after retries; not deleting. You can try again later.")
                // As a last resort, refresh vehicles to pick any newly persisted path and try once more
                await viewModel.loadVehicles()
                let refreshedPath = viewModel.parkedVehicles.first(where: { $0.id == parkedVehicle.id })?.photoPath?.trimmingCharacters(in: .whitespacesAndNewlines)
                if let refreshedPath = refreshedPath, !refreshedPath.isEmpty, refreshedPath.lowercased() != "nil", refreshedPath != photoPath {
                    print("[DEBUG] loadPhoto: Detected updated photoPath after reload: \(refreshedPath). Retrying once...")
                    do {
                        let finalData = try await SupabaseService.shared.downloadPhoto(path: refreshedPath)
                        if let image = UIImage(data: finalData) {
                            await MainActor.run { self.vehicleImage = image }
                            return
                        }
                    } catch {
                        print("[DEBUG] loadPhoto: Final retry after refresh failed: \(error)")
                    }
                }
                await MainActor.run { photoError = "Photo not available yet. Please try again in a moment." }
                return
            }
            // Fallback: try the old URL method but do NOT delete/close on failure
            print("[DEBUG] loadPhoto: Trying fallback URL method...")
            if let photoURL = SupabaseService.shared.photoURL(path: photoPath) {
                print("[DEBUG] loadPhoto: Fallback URL: \(photoURL)")
                do {
                    let (data, response) = try await URLSession.shared.data(from: photoURL)
                    if let httpResponse = response as? HTTPURLResponse {
                        print("[DEBUG] HTTP Response Status: \(httpResponse.statusCode)")
                        print("[DEBUG] Data size received: \(data.count) bytes")
                        if httpResponse.statusCode == 200, let image = UIImage(data: data) {
                            await MainActor.run { self.vehicleImage = image }
                        } else {
                            print("[DEBUG] loadPhoto: Fallback URL non-200 or invalid image; not deleting.")
                            await MainActor.run { photoError = "Couldn’t load the photo from the server." }
                        }
                    }
                } catch {
                    print("[DEBUG] loadPhoto: Fallback URL request failed: \(error)")
                    await MainActor.run { photoError = "Network error while loading the photo." }
                }
            } else {
                await MainActor.run { photoError = "Invalid photo URL." }
            }
        }
    }
    
    private func loadSpecificPhoto(path: String) async {
        do {
            let data = try await SupabaseService.shared.downloadPhoto(path: path)
            if let img = UIImage(data: data) {
                await MainActor.run { self.vehicleImage = img }
                return
            }
        } catch {
            // Try signed URL fallback is already inside downloadPhoto
            print("[DEBUG] loadSpecificPhoto error: \(error)")
        }
    }
    
    private func preloadThumbnails(paths: [String]) async {
        for path in paths {
            if galleryImages[path] != nil { continue }
            do {
                let data = try await SupabaseService.shared.downloadPhoto(path: path)
                if let img = UIImage(data: data) {
                    let thumb = resizeForThumb(img)
                    await MainActor.run { galleryImages[path] = thumb }
                }
            } catch {
                await MainActor.run { galleryErrors.insert(path) }
            }
        }
    }
    
    private func resizeForThumb(_ image: UIImage, target: CGFloat = 80) -> UIImage {
        let size = image.size
        let scale = min(target / max(size.width, size.height), 1)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let newImg = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImg ?? image
    }
    
    private func cleanupMissingImage() async {
        print("[DEBUG] cleanupMissingImage: Starting cleanup for vehicle \(parkedVehicle.id)")
        
        var updatedVehicle = parkedVehicle
        updatedVehicle = ParkedVehicle(
            id: parkedVehicle.id,
            vehicleId: parkedVehicle.vehicleId,
            airportName: parkedVehicle.airportName,
            garageName: parkedVehicle.garageName,
            parkingSpot: parkedVehicle.parkingSpot,
            dateParked: parkedVehicle.dateParked,
            photoPath: "", // Remove the invalid photoPath (empty string to ensure DB write)
            addedById: parkedVehicle.addedById,
            addedBy: parkedVehicle.addedBy,
            airTag: parkedVehicle.airTag,
            notes: parkedVehicle.notes,
            createdAt: parkedVehicle.createdAt,
            vehicle: parkedVehicle.vehicle
        )
        
        do {
            // Use the notes update method since we're not changing the photo, just removing the path
            try await viewModel.updateParkedVehicleNotes(updatedVehicle, notes: updatedVehicle.notes)
            print("[DEBUG] cleanupMissingImage: Successfully cleaned up database")
        } catch {
            print("[DEBUG] cleanupMissingImage: Failed to clean up database: \(error)")
        }
    }
    
    private func testImageURL(_ url: URL) async {
        print("[DEBUG] Testing image URL accessibility...")
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD" // Just get headers, not the full image
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                print("[DEBUG] HEAD request status: \(httpResponse.statusCode)")
                print("[DEBUG] HEAD request headers: \(httpResponse.allHeaderFields)")
            }
        } catch {
            print("[DEBUG] HEAD request failed: \(error)")
        }
    }
    
    private func saveNotes() async {
        isSavingNotes = true
        defer { isSavingNotes = false }
        
        let trimmedNotes = editedNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalNotes = trimmedNotes.isEmpty ? nil : trimmedNotes
        
        do {
            try await viewModel.updateParkedVehicleNotes(parkedVehicle, notes: finalNotes)
            showEditNotes = false
        } catch {
            print("Failed to update notes: \(error)")
        }
    }
}

struct LocationView: View {
    let coordinate: CLLocationCoordinate2D
    
    var body: some View {
        Map {
            Marker("Vehicle Location", coordinate: coordinate)
        }
        .ignoresSafeArea()
    }
}

extension CLLocationCoordinate2D {
    var id: String {
        "\(latitude)-\(longitude)"
    }
}

struct CustomLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon
            configuration.title
        }
    }
}

struct ParkedVehicleCard_Previews: PreviewProvider {
    static var previews: some View {
        ParkedVehicleCard(
            parkedVehicle: ParkedVehicle(
                id: UUID(),
                vehicleId: "test-id",
                airportName: "Test Airport",
                garageName: "Test Garage",
                parkingSpot: "A1",
                dateParked: Date(),
                photoPath: nil,
                addedById: "test-user-id",
                addedBy: "Test User",
                vehicle: Vehicle(
                    id: UUID(),
                    make: "Test Make",
                    model: "Test Model",
                    plate: "TEST123",
                    airTag: nil
                )
            ),
            isHistoryView: false
        )
        .previewLayout(.sizeThatFits)
    }
} 