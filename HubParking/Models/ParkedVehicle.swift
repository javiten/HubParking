import Foundation
import SwiftUI
import CoreLocation

struct ParkedVehicle: Identifiable, Codable {
    let id: UUID
    let vehicleId: String
    let airportName: String
    let garageName: String?
    let parkingSpot: String?
    let dateParked: Date
    let photoPath: String?
    let addedById: String?
    var addedBy: String
    let airTag: AirTag?
    let notes: String?
    let createdAt: Date?
    let vehicle: Vehicle
    
    var eventType: String = "pickup"
    var uiImage: UIImage?
    
    // Interpret 'photo' column as either a single path or a JSON array of paths
    var photoPaths: [String] {
        guard let raw = photoPath?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty, raw.lowercased() != "nil" else {
            return []
        }
        if raw.first == "[", let data = raw.data(using: .utf8) {
            if let arr = try? JSONDecoder().decode([String].self, from: data) {
                return arr
            }
        }
        return [raw]
    }
    
    var vehicle_id: String {
        vehicleId
    }
    
    var airport_name: String {
        airportName
    }
    
    var garage_name: String? {
        garageName
    }
    
    var parking_spot: String? {
        parkingSpot
    }
    
    var date_parked: Date {
        dateParked
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case vehicleId = "vehicle_id"
        case airportName = "airport_name"
        case garageName = "garage_name"
        case parkingSpot = "parking_spot"
        case dateParked = "date_parked"
        case photoPath = "photo"
        case addedById = "added_by_id"
        case addedBy = "added_by"
        case airTag = "air_tag"
        case notes
        case eventType = "event_type"
        case createdAt = "created_at"
        case vehicle
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        eventType = try container.decodeIfPresent(String.self, forKey: .eventType) ?? "pickup"
        id = try container.decode(UUID.self, forKey: .id)
        vehicleId = try container.decode(String.self, forKey: .vehicleId)
        airportName = try container.decode(String.self, forKey: .airportName)
        garageName = try container.decodeIfPresent(String.self, forKey: .garageName)
        parkingSpot = try container.decodeIfPresent(String.self, forKey: .parkingSpot)
        dateParked = try container.decode(Date.self, forKey: .dateParked)
        photoPath = try container.decodeIfPresent(String.self, forKey: .photoPath)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        addedById = try container.decodeIfPresent(String.self, forKey: .addedById)
        
        // Try to decode addedBy, fall back to "Unknown" if missing
        if let addedBy = try? container.decode(String.self, forKey: .addedBy) {
            self.addedBy = addedBy
        } else {
            self.addedBy = "Unknown"
        }
        
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        vehicle = try container.decode(Vehicle.self, forKey: .vehicle)
        
        if let airTagData = try container.decodeIfPresent([String: String].self, forKey: .airTag),
           let name = airTagData["name"] {
            airTag = AirTag(id: UUID(), name: name)
        } else {
            airTag = nil
        }
    }
    
    init(
        id: UUID = UUID(),
        vehicleId: String,
        airportName: String,
        garageName: String?,
        parkingSpot: String?,
        dateParked: Date = Date(),
        photoPath: String?,
        addedById: String? = nil,
        addedBy: String,
        airTag: AirTag? = nil,
        notes: String? = nil,
        createdAt: Date? = nil,
        vehicle: Vehicle
    ) {
        self.id = id
        self.vehicleId = vehicleId
        self.airportName = airportName
        self.garageName = garageName
        self.parkingSpot = parkingSpot
        self.dateParked = dateParked
        self.photoPath = photoPath
        self.addedById = addedById
        self.addedBy = addedBy
        self.airTag = airTag
        self.notes = notes
        self.createdAt = createdAt
        self.vehicle = vehicle
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(eventType, forKey: .eventType)
        try container.encode(id, forKey: .id)
        try container.encode(vehicle_id, forKey: .vehicleId)
        try container.encode(airport_name, forKey: .airportName)
        try container.encode(garage_name, forKey: .garageName)
        try container.encode(parking_spot, forKey: .parkingSpot)
        try container.encode(date_parked, forKey: .dateParked)
        try container.encode(vehicle, forKey: .vehicle)
        try container.encode(addedBy, forKey: .addedBy)
        
        if let photoPath = photoPath {
            try container.encode(photoPath, forKey: .photoPath)
        }
        if let airTag = airTag {
            try container.encode(["name": airTag.name], forKey: .airTag)
        }
        if let notes = notes {
            try container.encode(notes, forKey: .notes)
        }
        if let addedById = addedById {
            try container.encode(addedById, forKey: .addedById)
        }
        if let createdAt = createdAt {
            try container.encode(createdAt, forKey: .createdAt)
        }
    }
} 