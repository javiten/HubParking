import SwiftUI
import Foundation
import UIKit
import CoreLocation
import Network

class ParkedVehiclesViewModel: ObservableObject {
    @Published var parkedVehicles: [ParkedVehicle] = []
    @Published var vehicles: [Vehicle] = []
    @Published var pickupHistory: [ParkedVehicle] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    @Published var offlineQueue: [PendingOperation] = []
    @Published var isOffline = false
    
    private var usedAirTags: Set<String> = []
    
    private let parkedVehiclesKey = "parkedVehicles"
    private let pickupHistoryKey = "pickupHistory"
    private let offlineQueueKey = "offlineQueue"
    
    private var currentTask: Task<Void, Never>?
    private var lastLoadTime: Date = .distantPast
    private let minimumRefreshInterval: TimeInterval = 1.0  // Minimum time between refreshes
    
    private let networkMonitor = NWPathMonitor()
    
    // Add new properties for sync
    private var lastSyncTime: Date?
    private let syncInterval: TimeInterval = 30 // Sync every 30 seconds
    
    @AppStorage("currentUser") private var currentUser: String = ""
    
    enum PendingOperation: Codable, Equatable {
        case park(ParkedVehicle)
        case pickup(UUID)
        case update(ParkedVehicle)
        
        static func == (lhs: PendingOperation, rhs: PendingOperation) -> Bool {
            switch (lhs, rhs) {
            case (.park(let lhsVehicle), .park(let rhsVehicle)):
                return lhsVehicle.id == rhsVehicle.id
            case (.pickup(let lhsId), .pickup(let rhsId)):
                return lhsId == rhsId
            case (.update(let lhsVehicle), .update(let rhsVehicle)):
                return lhsVehicle.id == rhsVehicle.id
            default:
                return false
            }
        }
    }
    
    init() {
        loadPickupHistory()
        loadOfflineQueue()
        setupNetworkMonitoring()
        startHistorySync() // Start periodic sync
        
        Task { @MainActor in
            await loadVehicles()
            await syncHistory() // Initial sync
        }
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isOffline = path.status != .satisfied
                if path.status == .satisfied {
                    // Back online - process pending operations
                    await self?.processPendingOperations()
                }
            }
        }
        networkMonitor.start(queue: DispatchQueue.global())
    }
    
    private func loadOfflineQueue() {
        if let data = UserDefaults.standard.data(forKey: offlineQueueKey),
           let queue = try? JSONDecoder().decode([PendingOperation].self, from: data) {
            offlineQueue = queue
        }
    }
    
    private func saveOfflineQueue() {
        if let data = try? JSONEncoder().encode(offlineQueue) {
            UserDefaults.standard.set(data, forKey: offlineQueueKey)
        }
    }
    
    @MainActor
    private func processPendingOperations() async {
        guard !offlineQueue.isEmpty else { return }
        
        var completedOperations: [PendingOperation] = []
        
        for operation in offlineQueue {
            do {
                switch operation {
                case .park(let vehicle):
                    try await SupabaseService.shared.saveParkedVehicle(vehicle)
                    completedOperations.append(operation)
                case .pickup(let id):
                    try await SupabaseService.shared.deleteParkedVehicle(id: id)
                    completedOperations.append(operation)
                case .update(let vehicle):
                    try await SupabaseService.shared.updateParkedVehicle(vehicle)
                    completedOperations.append(operation)
                }
            } catch {
                print("Failed to process offline operation: \(error)")
                // Keep failed operations in queue
                break
            }
        }
        
        // Remove completed operations
        offlineQueue.removeAll { operation in
            completedOperations.contains(operation)
        }
        
        saveOfflineQueue()
        await loadVehicles()  // Refresh data
    }
    
    @MainActor
    func loadVehicles(force: Bool = false) async {
        // Prevent rapid reloading
        guard force || Date().timeIntervalSince(lastLoadTime) >= minimumRefreshInterval else {
            return
        }
        
        // Cancel any existing task
        currentTask?.cancel()
        
        let task = Task {
            do {
                print("\n=== Loading Vehicles ===")
                
                // Use async let to load both in parallel
                async let vehiclesTask = SupabaseService.shared.fetchVehicles()
                async let parkedVehiclesTask = SupabaseService.shared.fetchParkedVehicles()
                
                // Wait for both to complete
                let (vehicles, parkedVehicles) = try await (vehiclesTask, parkedVehiclesTask)
                
                // Check if cancelled before updating UI
                if Task.isCancelled { return }
                
                await MainActor.run {
                    self.vehicles = vehicles
                    self.parkedVehicles = parkedVehicles
                    self.lastLoadTime = Date()
                    self.error = nil
                }
            } catch {
                if !Task.isCancelled {
                    print("Error loading vehicles: \(error)")
                    await MainActor.run {
                        self.error = error
                    }
                }
            }
        }
        
        currentTask = task
        await task.value
    }
    
    @MainActor
    func refreshData() async throws {
        // Prevent rapid refreshing
        guard Date().timeIntervalSince(lastLoadTime) >= minimumRefreshInterval else {
            return
        }
        
        currentTask?.cancel()
        
        let task = Task {
            // Only show loading if data is empty
            if parkedVehicles.isEmpty {
                isLoading = true
            }
            defer { isLoading = false }
            
            do {
                async let vehiclesTask = SupabaseService.shared.fetchVehicles()
                async let parkedVehiclesTask = SupabaseService.shared.fetchParkedVehicles()
                
                let (vehicles, parkedVehicles) = try await (vehiclesTask, parkedVehiclesTask)
                
                guard !Task.isCancelled else { return }
                
                self.vehicles = vehicles
                self.parkedVehicles = parkedVehicles
                self.lastLoadTime = Date()
                self.error = nil
                
            } catch {
                if !Task.isCancelled {
                    self.error = error
                }
            }
        }
        
        currentTask = task
        await task.value
    }
    
    private func saveData() {
        if let data = try? JSONEncoder().encode(parkedVehicles) {
            UserDefaults.standard.set(data, forKey: parkedVehiclesKey)
        }
        
        if let data = try? JSONEncoder().encode(pickupHistory) {
            UserDefaults.standard.set(data, forKey: pickupHistoryKey)
        }
    }
    
    private func assignRandomAirTagsToExistingVehicles() {
        let availableAirTags = Set(AirTag.availableAirTags.map { $0.name })
        usedAirTags = Set(parkedVehicles.compactMap { $0.airTag?.name })
        
        var updatedVehicles = parkedVehicles
        for index in updatedVehicles.indices {
            if updatedVehicles[index].airTag == nil {
                let availableForUse = Array(availableAirTags.subtracting(usedAirTags))
                if let randomSerialNumber = availableForUse.randomElement() {
                    let newAirTag = TrackerDevice(id: UUID(), name: randomSerialNumber)
                    let vehicle = updatedVehicles[index]
                    
                    // Create new vehicle with AirTag
                    updatedVehicles[index] = ParkedVehicle(
                        id: vehicle.id,
                        vehicleId: vehicle.vehicleId,
                        airportName: vehicle.airportName,
                        garageName: vehicle.garageName,
                        parkingSpot: vehicle.parkingSpot,
                        dateParked: vehicle.dateParked,
                        photoPath: vehicle.photoPath,
                        addedById: vehicle.addedById,
                        addedBy: vehicle.addedBy,
                        airTag: AirTag(id: newAirTag.id, name: newAirTag.name),
                        notes: vehicle.notes,
                        createdAt: vehicle.createdAt,
                        vehicle: vehicle.vehicle
                    )
                    usedAirTags.insert(randomSerialNumber)
                }
            }
        }
        
        parkedVehicles = updatedVehicles
        saveData()
    }
    
    // Modified vehicle operations to handle offline mode
    @MainActor
    func parkVehicle(_ vehicle: Vehicle, at location: ParkedVehicle) async {
        do {
            if isOffline {
                offlineQueue.append(.park(location))
                saveOfflineQueue()
                // Update local state
                parkedVehicles.append(location)
            } else {
                try await SupabaseService.shared.saveParkedVehicle(location)
                await loadVehicles()
            }
        } catch {
            if (error as NSError).code == -1009 { // No internet connection
                offlineQueue.append(.park(location))
                saveOfflineQueue()
                // Update local state
                parkedVehicles.append(location)
            } else {
                print("Error parking vehicle: \(error)")
                self.error = error
            }
        }
    }
    
    @MainActor
    func deleteParkingCard(_ vehicle: ParkedVehicle, actor: String) async throws {
        // Prevent an older in-flight refresh from putting this card back on screen.
        currentTask?.cancel()
        await currentTask?.value
        try await SupabaseService.shared.deleteParkingCard(id: vehicle.id, actor: actor)
        withAnimation { parkedVehicles.removeAll { $0.id == vehicle.id } }
        var deleted = ParkedVehicle(id: vehicle.id, vehicleId: vehicle.vehicleId,
            airportName: vehicle.airportName, garageName: vehicle.garageName,
            parkingSpot: vehicle.parkingSpot, dateParked: vehicle.dateParked,
            photoPath: vehicle.photoPath, addedById: nil, addedBy: actor,
            airTag: vehicle.airTag, notes: vehicle.notes, createdAt: Date(), vehicle: vehicle.vehicle)
        deleted.eventType = "deleted"
        pickupHistory.removeAll { $0.id == deleted.id }
        pickupHistory.insert(deleted, at: 0)
        saveData()
        savePickupHistory()
    }

    @MainActor
    func pickupVehicle(_ vehicle: ParkedVehicle, pickedUpBy: String) async {
        do {
            print("=== Pickup Debug ===")
            print("Vehicle: \(vehicle.vehicle.make) \(vehicle.vehicle.model)")
            print("Picked up by: \(pickedUpBy)")
            print("Current user: \(currentUser)")
            
            // Create a new vehicle instance with the pickup user
            let pickedUpVehicle = ParkedVehicle(
                id: vehicle.id,
                vehicleId: vehicle.vehicleId,
                airportName: vehicle.airportName,
                garageName: vehicle.garageName,
                parkingSpot: vehicle.parkingSpot,
                dateParked: vehicle.dateParked,
                photoPath: vehicle.photoPath,
                addedById: nil,  // This will be set by SupabaseService
                addedBy: pickedUpBy,  // Make sure this is set correctly
                airTag: vehicle.airTag,
                notes: vehicle.notes,
                createdAt: Date(),
                vehicle: vehicle.vehicle
            )
            
            print("Created pickup vehicle with user: \(pickedUpVehicle.addedBy)")
            
            // First delete from parked vehicles
            try await SupabaseService.shared.deleteParkedVehicle(id: vehicle.id)
            
            // Then save to history
            try await SupabaseService.shared.saveParkingHistory(pickedUpVehicle)
            
            // Update local state after successful database operations
            withAnimation(.easeOut(duration: 0.3)) {
                parkedVehicles.removeAll { $0.id == vehicle.id }
                if !pickupHistory.contains(where: { $0.id == vehicle.id }) {
                    pickupHistory.insert(pickedUpVehicle, at: 0)
                }
            }
            
            // Save local state
            saveData()
            savePickupHistory()
            
            print("Pickup complete. Current parked count: \(parkedVehicles.count)")
            print("Current history count: \(pickupHistory.count)")
            printState()
            
            // Reload both lists to ensure UI is in sync
            await loadVehicles()
            await loadParkingHistory()
            
        } catch {
            print("Error during pickup: \(error)")
                self.error = error
                
                // Revert local state on error
                withAnimation {
                    if !parkedVehicles.contains(where: { $0.id == vehicle.id }) {
                        parkedVehicles.append(vehicle)
                    }
                    pickupHistory.removeAll { $0.id == vehicle.id }
                }
                saveData()
                savePickupHistory()
        }
    }
    
    @MainActor
    func restoreVehicle(_ vehicle: ParkedVehicle) async {
        // First update local state
        withAnimation {
            pickupHistory.removeAll { $0.id == vehicle.id }
            parkedVehicles.append(vehicle)
        }
        saveData()
        savePickupHistory()
        
        do {
            // Then update Supabase
            try await SupabaseService.shared.saveParkedVehicle(vehicle)
            try await SupabaseService.shared.deleteFromParkingHistory(id: vehicle.id)
            
            print("Vehicle restored: \(vehicle.vehicle.make) \(vehicle.vehicle.model)")
            printState()
            
        } catch let error as NSError {
            if error.code == -1009 { // Offline mode
                offlineQueue.append(.park(vehicle))
                saveOfflineQueue()
                print("Network unavailable - queued restore for later sync")
            } else {
                // Revert changes on error
                withAnimation {
                    parkedVehicles.removeAll { $0.id == vehicle.id }
                    pickupHistory.insert(vehicle, at: 0)
                }
                saveData()
                savePickupHistory()
                self.error = error
                print("Error restoring vehicle: \(error)")
            }
        }
    }
    
    @MainActor
    func createParkedVehicle(
        from vehicle: Vehicle,
        at airport: Airport,
        in garage: Garage,
        spot: String,
        photo: UIImage?,
        notes: String?,
        addedBy: String
    ) async throws {
        print("📝 Starting vehicle parking process...")
        
        try await SupabaseService.shared.createParkedVehicle(
            from: vehicle,
            at: airport,
            in: garage,
            spot: spot,
            photo: photo,
            notes: notes,
            addedBy: addedBy
        )
        
        print("✅ Vehicle saved to database, loading updated vehicles...")
        await loadVehicles()
        
        // Schedule notification after successful parking
        if let parkedVehicle = parkedVehicles.last {
            print("🔔 Found newly parked vehicle, checking notification status...")
            
            // Force check notification status
            NotificationManager.shared.checkNotificationStatus()
            
            // Add a small delay to ensure notification status is updated
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            if NotificationManager.shared.isNotificationsEnabled {
                print("✅ Notifications are enabled, scheduling notification...")
                NotificationManager.shared.scheduleParkedNotification(vehicle: parkedVehicle)
            } else {
                print("⚠️ Notifications are not enabled")
            }
        } else {
            print("⚠️ Could not find newly parked vehicle")
        }
    }
    
    func updateParkedVehicle(
        _ vehicle: ParkedVehicle,
        with photo: UIImage?,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws {
        var updatedVehicle = vehicle
        
        // Upload new photo if provided
        if let photo = photo {
            let uniqueID = vehicle.id.uuidString
            let photoPath = try await SupabaseService.shared.uploadPhoto(photo, for: uniqueID) { progress in
                progressHandler?(progress)
            }
            updatedVehicle = ParkedVehicle(
                id: vehicle.id,
                vehicleId: vehicle.vehicleId,
                airportName: vehicle.airportName,
                garageName: vehicle.garageName,
                parkingSpot: vehicle.parkingSpot,
                dateParked: vehicle.dateParked,
                photoPath: photoPath,
                addedById: vehicle.addedById,
                addedBy: vehicle.addedBy,
                airTag: vehicle.airTag,
                notes: vehicle.notes,
                createdAt: vehicle.createdAt,
                vehicle: vehicle.vehicle
            )
        }
        
        try await SupabaseService.shared.updateParkedVehicle(updatedVehicle)
        await loadVehicles()
    }
    
    @MainActor
    func updateParkedVehicleNotes(_ vehicle: ParkedVehicle, notes: String?) async throws {
        try await SupabaseService.shared.updateNotes(vehicleID: vehicle.id, notes: notes)
        if let index = parkedVehicles.firstIndex(where: { $0.id == vehicle.id }) {
            let current = parkedVehicles[index]
            parkedVehicles[index] = ParkedVehicle(
                id: current.id, vehicleId: current.vehicleId, airportName: current.airportName,
                garageName: current.garageName, parkingSpot: current.parkingSpot,
                dateParked: current.dateParked, photoPath: current.photoPath,
                addedById: current.addedById, addedBy: current.addedBy, airTag: current.airTag,
                notes: notes, createdAt: current.createdAt, vehicle: current.vehicle)
        }
    }

    func savePickupHistory() {
        do {
            let data = try JSONEncoder().encode(pickupHistory)
            UserDefaults.standard.set(data, forKey: "pickupHistory")
            print("Saved \(pickupHistory.count) vehicles to history")
        } catch {
            print("Error saving pickup history: \(error)")
        }
    }
    
    func loadPickupHistory() {
        if let data = UserDefaults.standard.data(forKey: "pickupHistory") {
            do {
                pickupHistory = try JSONDecoder().decode([ParkedVehicle].self, from: data)
                print("Loaded \(pickupHistory.count) vehicles from history")
            } catch {
                print("Error loading pickup history: \(error)")
                pickupHistory = []
            }
        }
    }
    
    @MainActor
    func undoPickup(_ vehicle: ParkedVehicle) async throws {
        currentTask?.cancel()
        await currentTask?.value
        var restored = vehicle
        restored.eventType = "pickup"
        try await SupabaseService.shared.restoreParkingCard(restored)
        withAnimation {
            pickupHistory.removeAll { $0.id == vehicle.id }
            parkedVehicles.removeAll { $0.id == restored.id }
            parkedVehicles.append(restored)
        }
        saveData()
        savePickupHistory()
    }

    @MainActor
    func clearPickupHistory() async {
        do {
            // First clear server history
            try await SupabaseService.shared.clearParkingHistory()
            print("Server history cleared")
            
            // Then clear local history with animation
            withAnimation {
                pickupHistory.removeAll()
            }
            savePickupHistory()
            
            print("Cleared pickup history")
            printState()
            
            // Reload to ensure everything is in sync
            await loadParkingHistory()
            
        } catch {
            print("Error clearing history: \(error)")
            self.error = error
        }
    }
    
    @MainActor
    func loadParkingHistory() async {
        do {
            let history = try await SupabaseService.shared.fetchParkingHistory()
            print("Loaded \(history.count) history items from server")
            
            withAnimation {
                pickupHistory = history
            }
            savePickupHistory()
            printState()
        } catch {
            print("Error loading parking history: \(error)")
            // Load from local storage as fallback
            loadPickupHistory()
        }
    }
    
    // Add this helper function to check state
    func printState() {
        print("\n=== Current State ===")
        print("Parked Vehicles:")
        for vehicle in parkedVehicles {
            print("- \(vehicle.vehicle.make) \(vehicle.vehicle.model)")
        }
        print("\nHistory:")
        for vehicle in pickupHistory {
            print("- \(vehicle.vehicle.make) \(vehicle.vehicle.model)")
        }
        print("==================\n")
    }
    
    // Add real-time sync for history
    private func startHistorySync() {
        // Set up initial sync
        Task {
            await syncHistory()
        }
        
        // Set up periodic sync
        Task {
            while true {
                try? await Task.sleep(nanoseconds: UInt64(15 * 1_000_000_000)) // Sync every 15 seconds
                if !Task.isCancelled {
                    await syncHistory()
                }
            }
        }
    }
    
    @MainActor
    func syncHistory() async {
        guard !isOffline else {
            print("Skipping sync - offline mode")
            return
        }
        
        print("Starting history sync...")
        do {
            let serverHistory = try await SupabaseService.shared.fetchParkingHistory()
            
            // Only update if there are changes
            if !areHistoriesEqual(serverHistory, pickupHistory) {
                withAnimation {
                    pickupHistory = serverHistory
                }
                savePickupHistory()
                print("History updated with server changes")
            } else {
                print("No history changes detected")
            }
            
            printState()
            
        } catch {
            print("Error during history sync: \(error)")
        }
    }
    
    private func areHistoriesEqual(_ first: [ParkedVehicle], _ second: [ParkedVehicle]) -> Bool {
        guard first.count == second.count else { return false }
        return Set(first.map { $0.id }) == Set(second.map { $0.id })
    }
    
    @MainActor
    private func uploadPhoto(_ photo: UIImage, for uniqueID: String) async throws -> String {
        // Compress the image before upload
        guard let compressedImageData = photo.jpegData(compressionQuality: 0.5) else {
            throw NSError(domain: "ImageCompression", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to compress image"])
        }
        
        // Convert compressed data back to UIImage
        guard let compressedImage = UIImage(data: compressedImageData) else {
            throw NSError(domain: "ImageCompression", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to create image from compressed data"])
        }
        
        // Try to upload the compressed image
        return try await SupabaseService.shared.uploadPhoto(compressedImage, for: uniqueID) { progress in
            print("Upload progress: \(progress)")
        }
    }
    
    func returnVehicle(_ vehicle: ParkedVehicle) async {
        do {
            // Save vehicle back to parked_vehicles
            try await SupabaseService.shared.saveParkedVehicle(vehicle)
            
            // Remove from pickup history
            if let index = pickupHistory.firstIndex(where: { $0.id == vehicle.id }) {
                pickupHistory.remove(at: index)
                savePickupHistory()
            }
            
            // Reload parked vehicles
            await loadVehicles()
        } catch {
            print("Error returning vehicle: \(error)")
        }
    }
    
    /// Append multiple photos to a vehicle and persist as JSON array in `photo` column
    @MainActor
    func addPhotos(_ photos: [UIImage], to vehicle: ParkedVehicle, progress: ((Int, Double) -> Void)? = nil) async throws {
        guard !photos.isEmpty else { return }
        let vehicle = parkedVehicles.first(where: { $0.id == vehicle.id }) ?? vehicle
        let uniqueID = vehicle.id.uuidString
        let newPaths = try await SupabaseService.shared.uploadPhotos(photos, for: uniqueID) { index, p in
            progress?(index, p)
        }
        var combined = vehicle.photoPaths
        combined.append(contentsOf: newPaths)
        let photoJSON: String
        if let data = try? JSONEncoder().encode(combined), let s = String(data: data, encoding: .utf8) {
            photoJSON = s
        } else {
            photoJSON = combined.joined(separator: ",")
        }
        let updated = ParkedVehicle(
            id: vehicle.id,
            vehicleId: vehicle.vehicleId,
            airportName: vehicle.airportName,
            garageName: vehicle.garageName,
            parkingSpot: vehicle.parkingSpot,
            dateParked: vehicle.dateParked,
            photoPath: photoJSON,
            addedById: vehicle.addedById,
            addedBy: vehicle.addedBy,
            airTag: vehicle.airTag,
            notes: vehicle.notes,
            createdAt: vehicle.createdAt,
            vehicle: vehicle.vehicle
        )
        try await SupabaseService.shared.updateParkedVehicle(updated)
        await loadVehicles(force: true)
    }
    
    // Add a helper function to create ParkedVehicle instances
    private func createParkedVehicleInstance(
        id: UUID = UUID(),
        vehicleId: String,
        airportName: String,
        garageName: String?,
        parkingSpot: String?,
        dateParked: Date = Date(),
        photoPath: String?,
        addedById: String?,
        addedBy: String,
        airTag: AirTag? = nil,
        notes: String? = nil,
        createdAt: Date? = nil,
        vehicle: Vehicle
    ) -> ParkedVehicle {
        ParkedVehicle(
            id: id,
            vehicleId: vehicleId,
            airportName: airportName,
            garageName: garageName,
            parkingSpot: parkingSpot,
            dateParked: dateParked,
            photoPath: photoPath,
            addedById: addedById,
            addedBy: addedBy,
            airTag: airTag,
            notes: notes,
            createdAt: createdAt,
            vehicle: vehicle
        )
    }
    
    private func createPreviewVehicle() -> ParkedVehicle {
        createParkedVehicleInstance(
            vehicleId: "test-id",
            airportName: "Test Airport",
            garageName: "Test Garage",
            parkingSpot: "A1",
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
        )
    }
} 