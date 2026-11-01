import Foundation

struct AirTag: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    
    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
    
    static let availableAirTags = [
        AirTag(name: "IPJ"),
        AirTag(name: "IP11"),
        AirTag(name: "IPXR")
    ]
} 