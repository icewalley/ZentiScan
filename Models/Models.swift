
import Foundation

// MARK: - Models

struct Checkpoint: Identifiable, Codable {
    let id: Int
    let text: String // oppgavetekst
    let description: String?
    let type: String // 'Manuell', 'Måling', etc.
    let criticality: String?
    let canFetchAutomatically: Bool?
    
    // Mapping from explicit DB columns to Swift friendly names
    enum CodingKeys: String, CodingKey {
        case id = "sjekkpunktid"
        case text = "oppgavetekst"
        case description = "beskrivelse"
        case type
        case criticality = "kritikalitet"
        case canFetchAutomatically = "kanHentesAutomatisk"
    }
}

struct ChecklistRegistration: Codable {
    let code: String
    let points: [ChecklistPointResult]
    let responsible: String
}

struct ChecklistPointResult: Codable {
    let sjekkpunktId: Int
    let oppgaveTekst: String
    let type: String
    let value: String?
    let status: String // "OK", "AVVIK", etc.
    let comment: String?
}

// Response wrapper for lookup
struct LookupResponse: Codable {
    let koblingid: Int
    let sjekkpunktid: Int
    let definition: Checkpoint?
    
    enum CodingKeys: String, CodingKey {
        case koblingid
        case sjekkpunktid
        case definition = "definisjon"
    }
}
