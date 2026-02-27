import Foundation

// MARK: - CMMS Data Models

struct Vedlikeholdsjobb: Codable, Identifiable, Hashable {
    let id: Int
    let tittel: String
    let beskrivelse: String?
    let status: JobStatus
    let type: JobType
    let bygningId: String?
    let romId: String?
    let planlagtStart: Date?
    let frist: Date?
    let faktiskStart: Date?
    let faktiskSlutt: Date?
    var oppgaver: [Vedlikeholdsoppgave]?

    enum JobStatus: String, Codable {
        case planlagt = "PLANLAGT"
        case pabegynt = "PABEGYNT"
        case utfort = "UTFORT"
        case avbrutt = "AVBRUTT"
        case godkjent = "GODKJENT"
    }

    enum JobType: String, Codable {
        case forebyggende = "FOREBYGGENDE"
        case akutt = "AKUTT"
        case inspeksjon = "INSPEKSJON"
        case oppgradering = "OPPGRADERING"
        case lovpalagt = "LOVPALAGT"
    }
}

struct Vedlikeholdsoppgave: Codable, Identifiable, Hashable {
    let id: Int
    let jobbId: Int
    let tittel: String
    let beskrivelse: String?
    let status: TaskStatus
    let kreverBilde: Bool
    let sensorRef: String?
    let autoVerdi: Double?
    let autoHentet: Bool
    let maaleVerdi: String?

    enum TaskStatus: String, Codable {
        case ok = "OK"
        case avvik = "AVVIK"
        case ikkeVurdert = "IKKE_VURDERT"
        case hoppetOver = "HOPPET_OVER"
    }
}

struct AvvikRegistrering: Codable {
    let oppgaveId: Int
    let beskrivelse: String
    let alvorlighet: Alvorlighet
    let bildeBase64: String?
    // Added for robustness
    let kilde: String = "ZentiScan iOS"

    enum Alvorlighet: String, Codable {
        case lav = "LAV"
        case medium = "MEDIUM"
        case hoy = "HOY"
        case kritisk = "KRITISK"
    }
}
