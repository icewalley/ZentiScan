
import Foundation
import CoreGraphics

// MARK: - Equipment Detection Models

/// Represents a piece of equipment detected by the camera
struct DetectedEquipment: Identifiable, Codable {
    let id: UUID
    let ns3457Code: String
    let confidence: Float
    let boundingBox: CGRect
    let suggestedName: String
    let category: EquipmentCategory
    let timestamp: Date
    
    init(id: UUID = UUID(), ns3457Code: String, confidence: Float, boundingBox: CGRect, suggestedName: String, category: EquipmentCategory) {
        self.id = id
        self.ns3457Code = ns3457Code
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.suggestedName = suggestedName
        self.category = category
        self.timestamp = Date()
    }
}

/// Equipment categories mapped to NS3457 Part 8
enum EquipmentCategory: String, Codable, CaseIterable {
    case hvac = "Ventilasjon"
    case plumbing = "Rør/Sanitær"
    case electrical = "Elektro"
    case fire = "Brann"
    case access = "Adgang"
    case heating = "Oppvarming"
    case cooling = "Kjøling"
    case control = "Styring"
    case other = "Annet"
    
    var icon: String {
        switch self {
        case .hvac: return "wind"
        case .plumbing: return "drop.fill"
        case .electrical: return "bolt.fill"
        case .fire: return "flame.fill"
        case .access: return "door.left.hand.open"
        case .heating: return "thermometer.high"
        case .cooling: return "snowflake"
        case .control: return "slider.horizontal.3"
        case .other: return "wrench.and.screwdriver"
        }
    }
    
    var color: String {
        switch self {
        case .hvac: return "blue"
        case .plumbing: return "cyan"
        case .electrical: return "yellow"
        case .fire: return "red"
        case .access: return "green"
        case .heating: return "orange"
        case .cooling: return "indigo"
        case .control: return "purple"
        case .other: return "gray"
        }
    }
}

// MARK: - NS3457 Code Mapping

/// Maps common equipment types to NS3457 codes
struct NS3457CodeMapping {
    /// Common equipment to NS3457 Part 8 code mappings
    static let mappings: [String: (code: String, name: String, category: EquipmentCategory)] = [
        // Pumps
        "pump": ("PU", "Pumpe", .plumbing),
        "water_pump": ("PU", "Vannpumpe", .plumbing),
        "circulation_pump": ("PU", "Sirkulasjonspumpe", .heating),
        
        // Fans & Ventilation
        "fan": ("VF", "Vifte", .hvac),
        "ventilator": ("VF", "Ventilator", .hvac),
        "air_handler": ("VF", "Luftbehandler", .hvac),
        "duct": ("KA", "Kanal", .hvac),
        
        // Valves
        "valve": ("VL", "Ventil", .plumbing),
        "gate_valve": ("VL", "Sluseventil", .plumbing),
        "check_valve": ("VL", "Tilbakeslagsventil", .plumbing),
        
        // Motors
        "motor": ("MO", "Motor", .electrical),
        "electric_motor": ("MO", "Elektrisk motor", .electrical),
        
        // Sensors
        "sensor": ("SE", "Sensor", .control),
        "temperature_sensor": ("SE", "Temperatursensor", .control),
        "pressure_sensor": ("SE", "Trykksensor", .control),
        "flow_sensor": ("SE", "Strømningsmåler", .control),
        
        // Fire Safety
        "fire_extinguisher": ("SL", "Brannslukker", .fire),
        "smoke_detector": ("BR", "Røykvarsler", .fire),
        "sprinkler": ("SP", "Sprinkler", .fire),
        
        // Heating
        "radiator": ("RA", "Radiator", .heating),
        "heater": ("VA", "Varmeapparat", .heating),
        "boiler": ("KJ", "Kjele", .heating),
        
        // Cooling
        "air_conditioner": ("KL", "Klimaanlegg", .cooling),
        "chiller": ("KL", "Kjølemaskin", .cooling),
        "cooling_tower": ("KT", "Kjøletårn", .cooling),
        
        // Electrical
        "switch": ("BR", "Bryter", .electrical),
        "panel": ("TA", "Tavle", .electrical),
        "transformer": ("TR", "Transformator", .electrical),
        
        // Access
        "door": ("DØ", "Dør", .access),
        "lock": ("LÅ", "Lås", .access),
        "card_reader": ("KO", "Kortleser", .access)
    ]
    
    /// Find the best matching NS3457 code for a detected object label
    static func findCode(for label: String) -> (code: String, name: String, category: EquipmentCategory)? {
        let normalizedLabel = label.lowercased().replacingOccurrences(of: " ", with: "_")
        
        // Direct match
        if let match = mappings[normalizedLabel] {
            return match
        }
        
        // Partial match
        for (key, value) in mappings {
            if normalizedLabel.contains(key) || key.contains(normalizedLabel) {
                return value
            }
        }
        
        return nil
    }
}

// MARK: - Generated Checklist

/// A checklist generated from detected equipment
struct GeneratedChecklist: Codable, Identifiable {
    let id: UUID
    let equipment: DetectedEquipment
    let checkpoints: [Checkpoint]
    let aiSuggestions: [String]?
    let generatedAt: Date
    
    init(equipment: DetectedEquipment, checkpoints: [Checkpoint], aiSuggestions: [String]? = nil) {
        self.id = UUID()
        self.equipment = equipment
        self.checkpoints = checkpoints
        self.aiSuggestions = aiSuggestions
        self.generatedAt = Date()
    }
}

// MARK: - API Request/Response Models

struct DetectionRequest: Codable {
    let imageBase64: String
    let deviceInfo: DeviceInfo?
}

struct DeviceInfo: Codable {
    let model: String
    let osVersion: String
    let appVersion: String
}

struct DetectionResponse: Codable {
    let detectedObjects: [DetectedEquipmentDTO]
    let suggestedCodes: [String]
    let processingTimeMs: Int?
}

struct DetectedEquipmentDTO: Codable {
    let ns3457Code: String
    let confidence: Float
    let suggestedName: String
    let category: String
    let boundingBox: BoundingBoxDTO?
}

struct BoundingBoxDTO: Codable {
    let x: Float
    let y: Float
    let width: Float
    let height: Float
}

struct GenerateChecklistRequest: Codable {
    let ns3457Code: String
    let context: String?
    let location: String?
}

struct GenerateChecklistResponse: Codable {
    let checkpoints: [Checkpoint]
    let aiTips: [String]?
    let estimatedTimeMinutes: Int?
}
