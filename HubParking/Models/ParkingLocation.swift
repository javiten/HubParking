import Foundation

struct Airport: Identifiable, Hashable, Equatable, Codable {
    let id: UUID
    let name: String
    let garages: [Garage]
    
    init(id: UUID = UUID(), name: String, garages: [Garage]) {
        self.id = id
        self.name = name
        self.garages = garages
    }
    
    // Add custom equality comparison
    static func == (lhs: Airport, rhs: Airport) -> Bool {
        lhs.name == rhs.name
    }
    
    // Add custom hash function
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

struct Garage: Identifiable, Hashable, Equatable, Codable {
    let id: UUID
    let name: String
    
    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
} 