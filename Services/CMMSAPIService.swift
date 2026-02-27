import Combine
import Foundation

/// Extension to APIManager that handles CMMS-specific API routes.
extension APIManager {

    // MARK: - CMMS Job Fetching

    /// Fetches the current user's assigned jobs (Dagens oppgaver)
    func getMineJobber() async throws -> [Vedlikeholdsjobb] {
        guard let url = URL(string: "\(baseURL)/cmms/mine-jobber") else {
            throw URLError(.badURL)
        }

        return try await fetch(url: url)
    }

    // MARK: - CMMS Job Lifecycle

    func startJobb(id: Int) async throws -> Vedlikeholdsjobb {
        return try await post("\(baseURL)/cmms/jobb/\(id)/start")
    }

    func pauseJobb(id: Int) async throws -> Vedlikeholdsjobb {
        return try await post("\(baseURL)/cmms/jobb/\(id)/pause")
    }

    func gjenopptaJobb(id: Int) async throws -> Vedlikeholdsjobb {
        return try await post("\(baseURL)/cmms/jobb/\(id)/gjenoppta")
    }

    func fullforJobb(id: Int) async throws -> Vedlikeholdsjobb {
        return try await post("\(baseURL)/cmms/jobb/\(id)/fullfor")
    }

    // MARK: - CMMS Tasks (Oppgaver)

    func fullforOppgave(id: Int, status: Vedlikeholdsoppgave.TaskStatus, maaleVerdi: String? = nil)
        async throws -> Vedlikeholdsoppgave
    {
        // Construct simple payload
        let payload: [String: String] = [
            "status": status.rawValue,
            "maaleVerdi": maaleVerdi ?? "",
        ]

        guard let url = URL(string: "\(baseURL)/cmms/oppgave/\(id)/fullfor") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
            (200...299).contains(httpResponse.statusCode)
        else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(Vedlikeholdsoppgave.self, from: data)
    }

    func autoFyllOppgaver(jobbId: Int) async throws -> [Vedlikeholdsoppgave] {
        return try await post("\(baseURL)/cmms/jobb/\(jobbId)/auto-fyll")
    }

    // MARK: - CMMS Deviations (Avvik)

    func registrerAvvik(registrering: AvvikRegistrering) async throws -> Bool {
        guard let url = URL(string: "\(baseURL)/cmms/avvik") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(registrering)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        return (200...299).contains(httpResponse.statusCode)
    }

    // MARK: - Helper Methods

    private func fetch<T: Decodable>(url: URL) async throws -> T {
        var request = URLRequest(url: url)
        // Add auth token if available (Mocked for now)
        request.setValue("Bearer YOUR_IOS_TOKEN", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
            (200...299).contains(httpResponse.statusCode)
        else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: data)
    }

    private func post<T: Decodable>(_ urlString: String) async throws -> T {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer YOUR_IOS_TOKEN", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
            (200...299).contains(httpResponse.statusCode)
        else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: data)
    }
}
