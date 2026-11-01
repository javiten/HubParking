import Foundation
import Supabase
import CoreLocation
import UIKit

class SupabaseService {
    static let shared = SupabaseService()
    
    private let client: SupabaseClient
    private var session: Session?
    
    // Add progress publisher
    @Published var uploadProgress: Double = 0
    
    
    private var uploadProgressObservation: NSKeyValueObservation?
    
    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: Bundle.main.object(forInfoDictionaryKey: "HubSupabaseURL") as? String ?? "https://invalid.local")!,
            supabaseKey: Bundle.main.object(forInfoDictionaryKey: "HubSupabaseAnonKey") as? String ?? ""
        )
    }
    
    func signIn(email: String, password: String) async throws {
        do {
            let authResponse = try await client.auth.signIn(
                email: email,
                password: password
            )
            print("=== Sign In Debug ===")
            print("Response type: \(type(of: authResponse))")
            
            self.session = authResponse
            print("Signed in successfully as: \(authResponse.user.email ?? "unknown")")
        } catch {
            print("Sign in failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    func signInAnonymously() async throws {
        do {
            print("Starting test account sign in...")
            let authResponse = try await client.auth.signIn(
                email: Bundle.main.object(forInfoDictionaryKey: "HubTestEmail") as? String ?? "",
                password: Bundle.main.object(forInfoDictionaryKey: "HubTestPassword") as? String ?? ""
            )
            
            print("=== Auth Response Debug ===")
            print("Response type: \(type(of: authResponse))")
            
            self.session = authResponse
            print("Authentication successful with user: \(authResponse.user.email ?? "unknown")")
            
        } catch {
            print("Error during anonymous sign in: \(error)")
            throw error
        }
    }
    
    // MARK: - Vehicles
    func fetchVehicles() async throws -> [Vehicle] {
        print("Fetching vehicles from Supabase...")
            let response: PostgrestResponse<[Vehicle]> = try await client
                .from("vehicles")
                .select()
            .order("make,model")
                .execute()
            
        let vehicles = response.value.filter { !$0.isArchived }
            print("Successfully loaded \(vehicles.count) vehicles")
            
            // Print first vehicle for debugging
            if let first = vehicles.first {
                print("First vehicle: \(first.make) \(first.model) \(first.plate)")
                if let airTag = first.airTag {
                    print("AirTag: \(airTag.name)")
                }
            }
            
            return vehicles
    }
    
    enum VehicleEditError: LocalizedError {
        case missingFields, duplicatePlate, vehicleInUse
        var errorDescription: String? {
            switch self {
            case .missingFields: return "Enter a make, model and license plate."
            case .duplicatePlate: return "Another vehicle already has that license plate."
            case .vehicleInUse: return "This vehicle has parking or pickup history records and cannot be deleted."
            }
        }
    }

    private struct VehicleFields: Encodable {
        let make: String
        let model: String
        let plate: String
        let airTag: [String: String]?
        enum CodingKeys: String, CodingKey { case make, model, plate; case airTag = "air_tag" }
        func encode(to encoder: Encoder) throws {
            var values = encoder.container(keyedBy: CodingKeys.self)
            try values.encode(make, forKey: .make)
            try values.encode(model, forKey: .model)
            try values.encode(plate, forKey: .plate)
            try values.encode(airTag, forKey: .airTag)
        }
    }

    func persistVehicle(_ vehicle: Vehicle, isNew: Bool) async throws -> Vehicle {
        guard !vehicle.make.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !vehicle.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !vehicle.plate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw VehicleEditError.missingFields
        }
        let existing = try await fetchVehicles()
        let plateKey = vehicle.plate.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !existing.contains(where: {
            $0.id != vehicle.id && $0.plate.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == plateKey
        }) else { throw VehicleEditError.duplicatePlate }
        if isNew {
            return try await client.from("vehicles").insert(vehicle).select().single().execute().value
        }
        let fields = VehicleFields(make: vehicle.make, model: vehicle.model, plate: vehicle.plate,
                                   airTag: vehicle.airTag.map { ["name": $0.name] })
        return try await client.from("vehicles").update(fields)
            .eq("id", value: vehicle.id).select().single().execute().value
    }

    func saveVehicle(_ vehicle: Vehicle) async throws {
        _ = try await persistVehicle(vehicle, isNew: true)
    }

    private struct VehicleReference: Decodable { let id: UUID }

    private struct ArchiveVehicle: Encodable { let is_archived: Bool }

    func deleteVehicle(_ id: UUID) async throws {
        // Keep the row for joins in current parking and pickup history.
        let _: Vehicle = try await client.from("vehicles")
            .update(ArchiveVehicle(is_archived: true))
            .eq("id", value: id).select().single().execute().value
    }

    func updateVehicleTracker(_ vehicle: Vehicle, name: String?) async throws -> Vehicle {
        let fields = VehicleFields(make: vehicle.make, model: vehicle.model, plate: vehicle.plate,
                                   airTag: name.map { ["name": $0] })
        return try await client.from("vehicles").update(fields)
            .eq("id", value: vehicle.id).select().single().execute().value
    }

    // MARK: - Parked Vehicles
    private struct User: Codable {
        let id: UUID
        let pin: String
        let name: String
    }
    
    private var userNameCache: [UUID: String] = [:]
    private var userIdCache: [String: UUID] = [:]  // Add this to store name -> ID mapping
    
    private func fetchUserNames() async throws {
        let response: PostgrestResponse<[User]> = try await client
            .from("users")
            .select()
            .execute()
        
        let users = response.value
        userNameCache = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0.name) })
        userIdCache = Dictionary(uniqueKeysWithValues: users.map { ($0.name, $0.id) })  // Add this
    }
    
    private func getUserId(for name: String) -> UUID? {
        return userIdCache[name]
    }
    
    private func mapUserIdToName(_ idString: String) -> String {
        if let uuid = UUID(uuidString: idString),
           let name = userNameCache[uuid] {
            return name
        }
        return idString
    }
    
    private struct InitialUser {
        let pin: String
        let name: String
    }
    
    private func ensureUsersExist() async throws {
        print("Checking for existing users...")
        let existingUsers = try await fetchUsers()
        print("Found \(existingUsers.count) existing users")
        
        if existingUsers.isEmpty {
            print("No users found. Creating initial users...")
            
            let initialUsers = [
                InitialUser(pin: Bundle.main.object(forInfoDictionaryKey: "HubPINJav") as? String ?? "", name: "Jav"),
                InitialUser(pin: Bundle.main.object(forInfoDictionaryKey: "HubPINLuca") as? String ?? "", name: "Luca"),
                InitialUser(pin: Bundle.main.object(forInfoDictionaryKey: "HubPINJuan") as? String ?? "", name: "Juan")
            ]
            
            for user in initialUsers {
                print("Creating user: \(user.name)")
                let newUser = User(
                    id: UUID(),
                    pin: user.pin,
                    name: user.name
                )
                try await saveUser(newUser)
                print("Successfully created user: \(user.name)")
            }
            
            print("Refreshing user cache...")
            try await fetchUserNames()
            print("User cache refreshed")
        } else {
            print("Users already exist: \(existingUsers.map { $0.name }.joined(separator: ", "))")
        }
    }
    
    func fetchParkedVehicles() async throws -> [ParkedVehicle] {
        // First ensure users exist and cache is populated
        try await ensureUsersExist()
        
        print("Fetching parked vehicles from Supabase...")
        let response: PostgrestResponse<[ParkedVehicle]> = try await client
            .from("parked_vehicles")
            .select("""
                id,
                vehicle_id,
                airport_name,
                garage_name,
                parking_spot,
                date_parked,
                photo,
                added_by_id,
                added_by,
                air_tag,
                notes,
                created_at,
                vehicle:vehicles(*)
            """)
            .order("created_at", ascending: false)
            .execute()
        
        var vehicles = response.value
        
        // Map user IDs to names
        for i in vehicles.indices {
            if let addedById = vehicles[i].addedById,
               let uuid = UUID(uuidString: addedById),
               let name = userNameCache[uuid] {
                vehicles[i].addedBy = name
            }
        }
        
        return vehicles
    }
    
    private struct ParkedVehicleUpsert: Encodable {
        let id: String
        let vehicle_id: UUID
        let airport_name: String
        let garage_name: String?
        let parking_spot: String?
        let date_parked: Date
        let photo: String?
        let added_by_id: String?
        let added_by: String
        let air_tag: [String: String]?
        let notes: String?
        let created_at: Date
        
        enum CodingKeys: String, CodingKey {
            case id, vehicle_id, airport_name, garage_name, parking_spot
            case date_parked, photo, added_by_id, added_by, air_tag, notes, created_at
        }
    }
    
    func saveParkedVehicle(_ vehicle: ParkedVehicle) async throws {
        // Ensure users exist and cache is populated
        try await ensureUsersExist()
        
        let data = ParkedVehicleUpsert(
            id: vehicle.id.uuidString,
            vehicle_id: UUID(uuidString: vehicle.vehicleId)!,
            airport_name: vehicle.airportName,
            garage_name: vehicle.garageName,
            parking_spot: vehicle.parkingSpot,
            date_parked: vehicle.dateParked,
            photo: vehicle.photoPath,
            added_by_id: getUserId(for: vehicle.addedBy)?.uuidString,
            added_by: vehicle.addedBy,
            air_tag: vehicle.airTag.map { ["name": $0.name] },
            notes: vehicle.notes,
            created_at: vehicle.createdAt ?? Date()
        )
        
        try await client
            .from("parked_vehicles")
            .insert(data)
            .execute()
    }
    
    func restoreParkingCard(_ vehicle: ParkedVehicle) async throws {
        if session == nil { try await signInAnonymously() }
        try await ensureUsersExist()
        let data = ParkedVehicleUpsert(
            id: vehicle.id.uuidString, vehicle_id: UUID(uuidString: vehicle.vehicleId)!,
            airport_name: vehicle.airportName, garage_name: vehicle.garageName,
            parking_spot: vehicle.parkingSpot, date_parked: vehicle.dateParked,
            photo: vehicle.photoPath, added_by_id: getUserId(for: vehicle.addedBy)?.uuidString,
            added_by: vehicle.addedBy, air_tag: vehicle.airTag.map { ["name": $0.name] },
            notes: vehicle.notes, created_at: vehicle.createdAt ?? Date())
        // Keep the original ID: retrying after a connection error must not create another card.
        let _: VehicleReference = try await client.from("parked_vehicles")
            .upsert(data, onConflict: "id").select("id").single().execute().value
        // Remove history only after the active card has been saved and acknowledged.
        let _: VehicleReference = try await client.from("parking_history").delete()
            .eq("id", value: vehicle.id).select("id").single().execute().value
    }

    func deleteParkedVehicle(id: UUID) async throws {
        try await client
            .from("parked_vehicles")
            .delete()
            .eq("id", value: id)
            .execute()
    }
    
    // MARK: - Users
    private func fetchUsers() async throws -> [User] {
        print("Fetching users from database...")
        let response: PostgrestResponse<[User]> = try await client
            .from("users")
            .select()
            .execute()
        
        let users = response.value
        print("Database returned \(users.count) users")
        return users
    }
    
    private func saveUser(_ user: User) async throws {
        print("Saving user: \(user.name)...")
        try await client
            .from("users")
            .insert(user)
            .execute()
        print("User saved successfully")
    }
    
    // MARK: - Enhanced Vehicle Methods
    func fetchVehicleByPlate(_ plate: String) async throws -> Vehicle? {
        let response: PostgrestResponse<[Vehicle]> = try await client
            .from("vehicles")
            .select()
            .eq("plate", value: plate)
            .execute()
        let vehicles = response.value
        return vehicles.first
    }
    
    // MARK: - Enhanced Parked Vehicle Methods
    func updateParkedVehicle(_ vehicle: ParkedVehicle) async throws {
        let data = ParkedVehicleUpsert(
            id: vehicle.id.uuidString,
            vehicle_id: UUID(uuidString: vehicle.vehicleId)!,
            airport_name: vehicle.airportName,
            garage_name: vehicle.garageName,
            parking_spot: vehicle.parkingSpot,
            date_parked: vehicle.dateParked,
            photo: vehicle.photoPath,
            added_by_id: getUserId(for: vehicle.addedBy)?.uuidString,
            added_by: vehicle.addedBy,
            air_tag: vehicle.airTag.map { ["name": $0.name] },
            notes: vehicle.notes,
            created_at: vehicle.createdAt ?? Date()
        )
        try await client
            .from("parked_vehicles")
            .update(data)
            .eq("id", value: vehicle.id)
            .execute()
    }
    
    func fetchParkedVehiclesByAirTag(_ airTagName: String) async throws -> [ParkedVehicle] {
        try await client
            .from("parked_vehicles")
            .select()
            .contains("air_tag", value: ["name": .string(airTagName)])
            .execute()
            .value
    }
    
    // Update upload method to use new API
    func uploadPhoto(_ photo: UIImage, for id: String, progress: @escaping (Double) -> Void) async throws -> String {
        // Ensure we're authenticated
        if session == nil {
            try await signInAnonymously()
        }
        
        let timestamp = Int(Date().timeIntervalSince1970)
        let path = "vehicle-photos/\(id)-\(timestamp).jpg"
        print("Uploading to path (storage client): \(path)")
        
        // Resize and compress
        let maxDimension: CGFloat = 800
        let resizedImage = resizeImage(photo, targetSize: maxDimension)
        var compressionQuality: CGFloat = 0.5
        var imageData: Data?
        while compressionQuality > 0.1 {
            imageData = resizedImage.jpegData(compressionQuality: compressionQuality)
            if let data = imageData {
                let sizeInMB = Double(data.count) / 1_000_000.0
                print("Image size at quality \(compressionQuality): \(String(format: "%.2f", sizeInMB))MB")
                if sizeInMB <= 0.8 { break }
            }
            compressionQuality -= 0.1
        }
        guard let finalImageData = imageData else {
            throw NSError(domain: "PhotoUpload", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to compress image"])
        }
        
        // Simple progress since storage client doesn't stream progress
        progress(0.1)
        
        // Upload via storage client with upsert
        let options = FileOptions(cacheControl: "3600", contentType: "image/jpeg", upsert: true)
        try await client.storage.from("vehicle-photos").upload(path, data: finalImageData, options: options)
        print("[DEBUG] uploadPhoto: Upload returned success for \(path), verifying availability...")

        // Verify availability (handle eventual consistency) by retrying a lightweight fetch
        let verifyDelays: [UInt64] = [200_000_000, 400_000_000, 800_000_000, 1_600_000_000]
        var available = false
        for (idx, delay) in verifyDelays.enumerated() {
            do {
                // Attempt to download to ensure object is readable
                _ = try await client.storage.from("vehicle-photos").download(path: path)
                available = true
                print("[DEBUG] uploadPhoto: Verified availability after retry \(idx)")
                break
            } catch {
                print("[DEBUG] uploadPhoto: Verify attempt \(idx+1) failed: \(error)")
                try? await Task.sleep(nanoseconds: delay)
            }
        }
        if !available {
            // One last attempt; if it still fails, surface a clear error so UI does not save bad path
            do {
                _ = try await client.storage.from("vehicle-photos").download(path: path)
                available = true
            } catch {
                print("[DEBUG] uploadPhoto: Final verification failed for \(path): \(error)")
                throw NSError(domain: "PhotoUpload", code: -2, userInfo: [NSLocalizedDescriptionKey: "Upload verification failed. Please try again."])
            }
        }

        progress(1.0)
        print("[DEBUG] uploadPhoto: Verified and returning path -> \(path)")
        return path
    }
    
    func uploadPhotos(_ photos: [UIImage], for id: String, progressEach: @escaping (Int, Double) -> Void) async throws -> [String] {
        var paths: [String] = []
        for (index, photo) in photos.enumerated() {
            let path = try await uploadPhoto(photo, for: id) { p in
                progressEach(index, p)
            }
            paths.append(path)
        }
        return paths
    }
    
    private func resizeImage(_ image: UIImage, targetSize: CGFloat) -> UIImage {
        let size = image.size
        let widthRatio  = targetSize / size.width
        let heightRatio = targetSize / size.height
        
        // Use the smaller ratio to ensure largest dimension is targetSize
        let newSize: CGSize
        if widthRatio > heightRatio {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio, height: size.height * widthRatio)
        }
        
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage ?? image
    }
    
    func downloadPhoto(path: String) async throws -> Data {
        // Ensure we're authenticated
        if session == nil {
            try await signInAnonymously()
        }
        let cleanPath = normalizeStoragePath(path)
        print("[DEBUG] downloadPhoto: Attempting to download from path: \(cleanPath)")
        
        do {
            let data = try await client.storage.from("vehicle-photos")
                .download(path: cleanPath)
            print("[DEBUG] downloadPhoto: Successfully downloaded \(data.count) bytes")
            return data
        } catch {
            print("[DEBUG] downloadPhoto: Error downloading photo: \(error)")
            // Fallback: try a signed URL in case the bucket is private or auth user differs
            do {
                let signedURL = try await client.storage.from("vehicle-photos").createSignedURL(path: cleanPath, expiresIn: 300)
                print("[DEBUG] downloadPhoto: Using signed URL fallback")
                let (data, response) = try await URLSession.shared.data(from: signedURL)
                if let http = response as? HTTPURLResponse {
                    print("[DEBUG] downloadPhoto: SignedURL status=\(http.statusCode), size=\(data.count)")
                }
                return data
            } catch {
                print("[DEBUG] downloadPhoto: Signed URL fallback failed: \(error)")
                throw error
            }
        }
    }
    
    func photoURL(path: String) -> URL? {
        let cleanPath = normalizeStoragePath(path)
        print("[DEBUG] photoURL input path: \(path), cleanPath: \(cleanPath)")
        
        // Try the Supabase public URL method first
        do {
            let url = try client.storage.from("vehicle-photos")
                .getPublicURL(path: cleanPath)
            print("[DEBUG] Successfully generated Supabase public URL: \(url)")
            return url
        } catch {
            print("[DEBUG] Error getting Supabase public URL: \(error)")
            
            // Fallback: try to construct a direct URL
            let fallbackURL = URL(string: "https://svczloyxwutpjhukpebb.supabase.co/storage/v1/object/public/vehicle-photos/\(cleanPath)")
            if let fallbackURL = fallbackURL {
                print("[DEBUG] Using fallback URL: \(fallbackURL)")
                return fallbackURL
            }
            
            print("[DEBUG] Failed to construct fallback URL")
            return nil
        }
    }
    
    // Alternative method that doesn't rely on Supabase client
    func alternativePhotoURL(path: String) -> URL? {
        let cleanPath = normalizeStoragePath(path)
        let directURL = URL(string: "https://svczloyxwutpjhukpebb.supabase.co/storage/v1/object/public/vehicle-photos/\(cleanPath)")
        print("[DEBUG] Alternative photo URL: \(directURL?.absoluteString ?? "nil")")
        return directURL
    }
    
    // MARK: - Parking History
    func fetchParkingHistory() async throws -> [ParkedVehicle] {
        // Ensure we're authenticated
        if session == nil {
            try await signInAnonymously()
        }
        
        // First ensure users exist and cache is populated
        try await ensureUsersExist()
        
        print("Fetching parking history...")
        let response: PostgrestResponse<[ParkedVehicle]> = try await client
            .from("parking_history")
            .select("*, vehicle:vehicles!parking_history_vehicle_id_fkey(*)")
            .order("date_parked", ascending: false)
            .execute()
        
        var history = response.value
        
        // Map user IDs to names
        for i in history.indices {
            if let addedById = history[i].addedById,
               let uuid = UUID(uuidString: addedById),
               let name = userNameCache[uuid] {
                history[i].addedBy = name
                print("Debug - Mapped user ID \(addedById) to name \(name)")
            }
        }
        
        print("Fetched \(history.count) history records")
        return history
    }
    
    func saveParkingHistory(_ vehicle: ParkedVehicle) async throws {
        print("Saving to parking history: \(vehicle.vehicle.make) \(vehicle.vehicle.model)")
        
        // First ensure we're authenticated
        if session == nil {
            try await signInAnonymously()
        }
        
        // First ensure users exist and cache is populated
        try await ensureUsersExist()
        
        // Get the user ID for the person picking up
        let userId = getUserId(for: vehicle.addedBy)
        print("Debug - User lookup: name=\(vehicle.addedBy), id=\(userId?.uuidString ?? "nil")")
        
        // First check if the vehicle is already in history
        let response: PostgrestResponse<[ParkedVehicleData]> = try await client
            .from("parking_history")
            .select()
            .eq("id", value: vehicle.id)
            .execute()
        
        if response.value.isEmpty {
            // Vehicle not in history, proceed with insert
            let data = ParkedVehicleUpsert(
                id: vehicle.id.uuidString,
                vehicle_id: UUID(uuidString: vehicle.vehicleId)!,
                airport_name: vehicle.airportName,
                garage_name: vehicle.garageName,
                parking_spot: vehicle.parkingSpot,
                date_parked: vehicle.dateParked,
                photo: vehicle.photoPath,
                added_by_id: userId?.uuidString,
                added_by: vehicle.addedBy,
                air_tag: vehicle.airTag.map { ["name": $0.name] },
                notes: vehicle.notes,
                created_at: Date()
            )
            
            print("Debug - Saving history record:")
            print("  - User: \(vehicle.addedBy)")
            print("  - User ID: \(userId?.uuidString ?? "nil")")
            
            try await client
                .from("parking_history")
                .insert(data)
                .execute()
            
            print("Successfully saved to history with user: \(vehicle.addedBy)")
        } else {
            print("Vehicle already exists in history, skipping insert")
        }
        
        // Delete from parked vehicles regardless
        try await deleteParkedVehicle(id: vehicle.id)
    }
    
    func deleteParkingCard(id: UUID, actor: String) async throws {
        // Use the same authenticated session as the existing history operations.
        if session == nil { try await signInAnonymously() }
        // One server transaction records the deletion and removes the active card.
        try await client.rpc("delete_parking_card", params: ["p_id": id.uuidString, "p_actor": actor]).execute()
    }

    func clearParkingHistory() async throws {
        print("Clearing parking history...")
        
        // First ensure we're authenticated
        if session == nil {
            try await signInAnonymously()
        }
        
        try await client
            .from("parking_history")
            .delete()
            .gte("id", value: "00000000-0000-0000-0000-000000000000")  // Match all UUIDs
            .execute()
        
        print("Parking history cleared successfully")
    }
    
    func deleteFromParkingHistory(id: UUID) async throws {
        try await client
            .from("parking_history")
            .delete()
            .eq("id", value: id)
            .execute()
    }
    
    func createParkedVehicle(
        from vehicle: Vehicle,
        at airport: Airport,
        in garage: Garage,
        spot: String,
        photo: UIImage?,
        notes: String?,
        addedBy: String
    ) async throws {
        // Ensure users exist and cache is populated
        try await ensureUsersExist()
        
        print("Creating parked vehicle with photo...")
        
        var photoPath: String? = nil
        if let photo = photo {
            let uniqueID = UUID().uuidString
            photoPath = try await uploadPhoto(photo, for: uniqueID) { progress in
                print("Upload progress: \(progress)")
            }
            print("Photo uploaded with path: \(photoPath ?? "none")")
        }
        
        // Get the user's UUID from the name
        let userId = userIdCache[addedBy]?.uuidString
        print("Creating vehicle with user: \(addedBy) (ID: \(userId ?? "unknown"))")
        
        let parkedVehicle = ParkedVehicle(
            id: UUID(),
            vehicleId: vehicle.id.uuidString,
            airportName: airport.name,
            garageName: garage.name,
            parkingSpot: spot,
            dateParked: Date(),
            photoPath: photoPath,
            addedById: userId,
            addedBy: addedBy,  // Use the provided name
            airTag: nil,
            notes: notes,
            createdAt: Date(),
            vehicle: vehicle
        )
        
        try await saveParkedVehicle(parkedVehicle)
    }
    
    func deletePhoto(path: String) async throws {
        let cleanPath = normalizeStoragePath(path)
        print("[DEBUG] deletePhoto: Attempting to delete path: \(cleanPath)")
        do {
            _ = try await client.storage.from("vehicle-photos").remove(paths: [cleanPath])
            print("[DEBUG] deletePhoto: Successfully deleted photo")
        } catch {
            print("[DEBUG] deletePhoto: Failed to delete photo: \(error)")
            throw error
        }
    }
    
    private func normalizeStoragePath(_ raw: String) -> String {
        // If the DB stored a JSON array, prefer the first element
        if raw.first == "[", let data = raw.data(using: .utf8), let arr = try? JSONDecoder().decode([String].self, from: data), let first = arr.first {
            return normalizeStoragePath(first)
        }
        // If already has a folder prefix, keep as-is (minus leading slash)
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let noSlash = trimmed.hasPrefix("/") ? String(trimmed.dropFirst()) : trimmed
        if noSlash.contains("/") { return noSlash }
        // If it’s just a filename, store under vehicle-photos/
        return "vehicle-photos/\(noSlash)"
    }
    
    private func lastComponent(_ s: String) -> String {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if let idx = trimmed.lastIndex(of: "/") { return String(trimmed[trimmed.index(after: idx)...]) }
        return trimmed
    }

    private func parsePhotoValue(_ value: String?) -> [String] {
        guard let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty, raw.lowercased() != "nil" else {
            return []
        }
        if raw.first == "[", let data = raw.data(using: .utf8), let arr = try? JSONDecoder().decode([String].self, from: data) {
            return arr
        }
        return [raw]
    }

    private struct PhotoOnlyUpdate: Encodable {
        let photo: String?
        enum CodingKeys: String, CodingKey { case photo }
        func encode(to encoder: Encoder) throws {
            var values = encoder.container(keyedBy: CodingKeys.self)
            try values.encode(photo, forKey: .photo)
        }
    }

    private struct NotesOnlyUpdate: Encodable {
        let notes: String?
        enum CodingKeys: String, CodingKey { case notes }
        func encode(to encoder: Encoder) throws {
            var values = encoder.container(keyedBy: CodingKeys.self)
            try values.encode(notes, forKey: .notes)
        }
    }

    func updateNotes(vehicleID: UUID, notes: String?) async throws {
        try await client.from("parked_vehicles")
            .update(NotesOnlyUpdate(notes: notes)).eq("id", value: vehicleID).execute()
    }

    /// Delete a photo from Storage and update the DB reference (supports array or single string).
    func removeVehiclePhoto(vehicleId: UUID, currentPhotoValue: String?, pathToRemove: String) async throws {
        let normalizedToRemove = normalizeStoragePath(pathToRemove)
        // Compute new photo value
        var paths = parsePhotoValue(currentPhotoValue)
        paths.removeAll { normalizeStoragePath($0) == normalizedToRemove }
        let newPhotoValue: String?
        if paths.isEmpty { newPhotoValue = nil }
        else if let data = try? JSONEncoder().encode(paths), let s = String(data: data, encoding: .utf8) { newPhotoValue = s }
        else { newPhotoValue = paths.joined(separator: ",") }
        // Persist only the photo column
        try await client
            .from("parked_vehicles")
            .update(PhotoOnlyUpdate(photo: newPhotoValue))
            .eq("id", value: vehicleId)
            .execute()
        // Remove the reference first: a database error must not leave a broken photo.
        do { _ = try await client.storage.from("vehicle-photos").remove(paths: [normalizedToRemove]) }
        catch { print("Storage cleanup failed after removing photo reference: \(error)") }

    }
}

struct LocationCoordinate: Codable {
    let latitude: Double
    let longitude: Double
    
    init(from coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }
} 