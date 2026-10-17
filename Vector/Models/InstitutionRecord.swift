import Foundation

struct InstitutionRecord: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var type: String
    var locality: String
    var regionID: String
    var address: String?
    var websiteURL: String?
    var admissionsPhone: String?
    var admissionsEmail: String?
    var admissionsURL: String?
    var sourceURL: String?
    var lastVerifiedAt: Date?
    var isActive: Bool

    init(
        id: String = UUID().uuidString,
        name: String = "",
        type: String = "university",
        locality: String = "",
        regionID: String = "",
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.locality = locality
        self.regionID = regionID
        self.address = nil
        self.websiteURL = nil
        self.admissionsPhone = nil
        self.admissionsEmail = nil
        self.admissionsURL = nil
        self.sourceURL = nil
        self.lastVerifiedAt = nil
        self.isActive = isActive
    }
}
