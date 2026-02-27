import Foundation
import SwiftUI

@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var isAuthenticated: Bool = false
    @Published var currentUser: AuthUser? = nil
    @Published var isCheckingAuth: Bool = true  // True while verifying token on launch

    private init() {
        // Automatically check token when manager is created
        Task {
            await checkAuthStatus()
        }
    }

    /// Verifies if the stored token is still valid.
    func checkAuthStatus() async {
        isCheckingAuth = true
        defer { isCheckingAuth = false }

        guard KeychainManager.shared.getToken() != nil else {
            isAuthenticated = false
            return
        }

        do {
            // First, see if we can get a silent MSAL token
            // If MSAL token expires, the backend token is likely also expired or we should refresh both
            if let msalToken = try? await MSALAuthService.shared.acquireTokenSilently() {
                // We have a valid MSAL session. Exchange it to ensure ZentiOS backend is synced
                try await exchangeMSALToken(msalToken: msalToken)
                return
            }

            // Re-use APIManager configuration to ping /auth
            guard let url = URL(string: "\(validateBaseUrl())/auth") else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"

            // Inject the token dynamically
            if let token = KeychainManager.shared.getToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                (200...299).contains(httpResponse.statusCode)
            else {
                logout()  // Token invalid
                return
            }

            // Decode user info if backend returns it on GET /api/ios/auth
            // Currently spec says "Token is valid", so we just sign them in.
            isAuthenticated = true

            // Try to parse user if available
            if let user = try? JSONDecoder().decode(AuthUser.self, from: data) {
                self.currentUser = user
            }

        } catch {
            logout()
        }
    }

    /// Exchange Microsoft token for Zenti JWT
    func exchangeMSALToken(msalToken: String) async throws {
        guard let url = URL(string: "\(validateBaseUrl())/auth/sso") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = SSOExchangeRequest(accessToken: msalToken)
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if (200...299).contains(httpResponse.statusCode) {
            let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
            await MainActor.run {
                self.login(withResponse: loginResponse)
            }
        } else {
            throw URLError(.userAuthenticationRequired)
        }
    }

    /// Store token and update state
    func login(withResponse response: LoginResponse) {
        let success = KeychainManager.shared.saveToken(response.token)
        if success {
            self.currentUser = response.user
            self.isAuthenticated = true
        }
    }

    /// Clear token and update state
    func logout() {
        KeychainManager.shared.deleteToken()
        try? MSALAuthService.shared.signOut()
        self.currentUser = nil
        self.isAuthenticated = false
    }

    // Temporary helper to get the base URL since APIManager may not be injected here cleanly yet
    private func validateBaseUrl() -> String {
        return APIManager.shared.baseURL
    }
}
