import Foundation

struct Vehicle: Identifiable, Codable, Equatable {
    let id: UUID
    let make: String
    let model: String
    let plate: String
    let airTag: TrackerDevice?
    let createdAt: Date?
    let isArchived: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case make
        case model
        case plate
        case airTag = "air_tag"
        case createdAt = "created_at"
        case isArchived = "is_archived"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        id = try container.decode(UUID.self, forKey: .id)
        make = try container.decode(String.self, forKey: .make)
        model = try container.decode(String.self, forKey: .model)
        plate = try container.decode(String.self, forKey: .plate)
        
        // Handle the air_tag JSONB structure: {"name": "IPJ"}
        if let airTagDict = try container.decodeIfPresent([String: String].self, forKey: .airTag),
           let name = airTagDict["name"] {
            airTag = TrackerDevice(id: UUID(), name: name)
        } else {
            airTag = nil
        }
        
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
    }
    
    init(id: UUID = UUID(), make: String, model: String, plate: String, airTag: TrackerDevice? = nil) {
        self.id = id
        self.make = make
        self.model = model
        self.plate = plate
        self.airTag = airTag
        self.createdAt = nil
        self.isArchived = false
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(make, forKey: .make)
        try container.encode(model, forKey: .model)
        try container.encode(plate, forKey: .plate)
        
        // Encode air_tag as {"name": "IPJ"}
        if let airTag = airTag {
            try container.encode(["name": airTag.name], forKey: .airTag)
        }
        
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
    }
    
    var description: String {
        "\(make) \(model) \(plate)"
    }
}

struct TrackerDevice: Codable, Equatable {
    let id: UUID
    let name: String
    
    private enum CodingKeys: String, CodingKey {
        case id
        case name
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
    }
    
    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
} 