import Foundation

struct User: Identifiable, Codable {
    let id: UUID
    let pin: String
    let name: String
    
    static let authorizedUsers = [
        User(id: UUID(uuidString: "3326A5E1-2F3B-4C8D-9E1A-B5F9C2A8D3E7")!, pin: Bundle.main.object(forInfoDictionaryKey: "HubPINJav") as? String ?? "", name: "Jav"),
        User(id: UUID(uuidString: "2030B4F2-1E2C-4D8E-8F1B-A4E8D3C7B2A6")!, pin: Bundle.main.object(forInfoDictionaryKey: "HubPINLuca") as? String ?? "", name: "Luca"),
        User(id: UUID(uuidString: "2403C3E3-3D4A-4B7F-7E1C-C3F7E2B1A5D4")!, pin: Bundle.main.object(forInfoDictionaryKey: "HubPINJuan") as? String ?? "", name: "Juan")
    ]
} 