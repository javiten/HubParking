import Foundation

struct VehicleLocation: Identifiable {
    let id = UUID()
    let vehicleInfo: String
    let location: String
    let dateParked: Date
    let notes: String?
} 