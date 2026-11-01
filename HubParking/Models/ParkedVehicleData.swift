import Foundation
import Supabase

struct ParkedVehicleData: Codable {
    let id: UUID
    let vehicleId: String
    let airportName: String
    let garageName: String?
    let parkingSpot: String?
    let dateParked: Date
    var photo: String?
    let addedById: String?
    let addedBy: String
    let airTag: [String: String]?
    let notes: String?
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case vehicleId = "vehicle_id"
        case airportName = "airport_name"
        case garageName = "garage_name"
        case parkingSpot = "parking_spot"
        case dateParked = "date_parked"
        case photo
        case addedById = "added_by_id"
        case addedBy = "added_by"
        case airTag = "air_tag"
        case notes
        case createdAt = "created_at"
    }
    
    init(from vehicle: ParkedVehicle, session: Session?) {
        self.id = vehicle.id
        self.vehicleId = vehicle.vehicleId
        self.airportName = vehicle.airportName
        self.garageName = vehicle.garageName
        self.parkingSpot = vehicle.parkingSpot
        self.dateParked = vehicle.dateParked
        self.photo = vehicle.photoPath
        self.addedById = session?.user.id.uuidString.lowercased()
        self.addedBy = vehicle.addedBy
        self.airTag = vehicle.airTag.map { ["name": $0.name] }
        self.notes = vehicle.notes
        self.createdAt = Date()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id.uuidString.lowercased(), forKey: .id)
        try container.encode(vehicleId, forKey: .vehicleId)
        try container.encode(airportName, forKey: .airportName)
        try container.encode(garageName, forKey: .garageName)
        try container.encode(parkingSpot, forKey: .parkingSpot)
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        try container.encode(formatter.string(from: dateParked), forKey: .dateParked)
        
        if let addedById = addedById {
            try container.encode(addedById, forKey: .addedById)
        }
        try container.encode(addedBy, forKey: .addedBy)
        if let airTag = airTag {
            try container.encode(airTag, forKey: .airTag)
        }
        if let notes = notes {
            try container.encode(notes, forKey: .notes)
        }
        if let photo = photo {
            try container.encode(photo, forKey: .photo)
        }
        if let createdAt = createdAt {
            try container.encode(createdAt, forKey: .createdAt)
        }
    }
} 