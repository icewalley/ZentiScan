
import Foundation
import Combine
import SwiftUI

/// Extended API Manager with equipment detection and checklist generation endpoints
class APIManager: ObservableObject {
    static let shared = APIManager()
    
    // CHANGE THIS to your Mac's local IP if testing on real device
    // e.g., "http://192.168.1.150:3000/api"
    // For Simulator, localhost usually works
    private let baseURL = "http://localhost:3000/api"
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
    
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()
    
    // MARK: - Original Methods
    
    func lookupCheckpoints(for code: String) async throws -> [Checkpoint] {
        guard let url = URL(string: "\(baseURL)/lookup?code=\(code)") else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        // The API returns SjekkpunktKobling[] which has 'definisjon' inside
        let wrappers = try JSONDecoder().decode([LookupResponse].self, from: data)
        return wrappers.compactMap { $0.definition }
    }
    
    func submitRegistration(registration: ChecklistRegistration) async throws {
        guard let url = URL(string: "\(baseURL)/registrations") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(registration)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
    }
    
    // MARK: - New Equipment Detection Methods
    
    /// Send image to server for AI-powered equipment detection
    func detectEquipment(request: DetectionRequest) async throws -> DetectionResponse {
        guard let url = URL(string: "\(baseURL)/ios/detect") else {
            throw URLError(.badURL)
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 30 // Allow time for AI processing
        
        urlRequest.httpBody = try encoder.encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode == 200 {
            return try decoder.decode(DetectionResponse.self, from: data)
        } else if httpResponse.statusCode == 404 {
            // Endpoint not yet implemented, return empty response
            return DetectionResponse(detectedObjects: [], suggestedCodes: [], processingTimeMs: nil)
        } else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw DetectionError.serverError(errorBody)
        }
    }
    
    /// Generate a checklist for a specific NS3457 code
    func generateChecklist(for code: String, context: String? = nil, location: String? = nil) async throws -> GenerateChecklistResponse {
        guard let url = URL(string: "\(baseURL)/ios/generate-checklist") else {
            throw URLError(.badURL)
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 20
        
        let requestBody = GenerateChecklistRequest(
            ns3457Code: code,
            context: context,
            location: location
        )
        
        urlRequest.httpBody = try encoder.encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode == 200 {
            return try decoder.decode(GenerateChecklistResponse.self, from: data)
        } else if httpResponse.statusCode == 404 {
            // Fallback: Use the existing lookup endpoint
            let checkpoints = try await lookupCheckpoints(for: code)
            return GenerateChecklistResponse(
                checkpoints: checkpoints,
                aiTips: nil,
                estimatedTimeMinutes: checkpoints.count * 2
            )
        } else {
            throw URLError(.badServerResponse)
        }
    }
    
    /// Get all available NS3457 codes for browsing
    func getAllNS3457Codes() async throws -> [NS3457CodeInfo] {
        guard let url = URL(string: "\(baseURL)/ns3457/codes") else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        return try decoder.decode([NS3457CodeInfo].self, from: data)
    }
    
    /// Search for NS3457 codes by keyword
    func searchNS3457(query: String) async throws -> [NS3457CodeInfo] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/ns3457/search?q=\(encodedQuery)") else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        return try decoder.decode([NS3457CodeInfo].self, from: data)
    }
    
    /// Submit completed checklist results
    func submitChecklistResults(_ results: ChecklistSubmission) async throws -> SubmissionResult {
        guard let url = URL(string: "\(baseURL)/ios/submit-checklist") else {
            throw URLError(.badURL)
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try encoder.encode(results)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
            return try decoder.decode(SubmissionResult.self, from: data)
        } else {
            // Fallback to old endpoint
            let oldRegistration = ChecklistRegistration(
                code: results.ns3457Code,
                points: results.results,
                responsible: results.performedBy
            )
            try await submitRegistration(registration: oldRegistration)
            return SubmissionResult(success: true, jobId: nil, message: "Registrert via fallback")
        }
    }
}

// MARK: - Additional Models

struct NS3457CodeInfo: Codable, Identifiable {
    var id: String { code }
    let code: String
    let name: String
    let description: String?
    let category: String?
    let checkpointCount: Int?
}

struct ChecklistSubmission: Codable {
    let ns3457Code: String
    let equipmentId: String?
    let location: String?
    let performedBy: String
    let results: [ChecklistPointResult]
    let photos: [String]? // Base64 encoded photos
    let notes: String?
    let completedAt: Date
}

struct SubmissionResult: Codable {
    let success: Bool
    let jobId: Int?
    let message: String?
}
