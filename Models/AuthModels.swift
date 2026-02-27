import Foundation

// MARK: - Auth Models

struct AuthUser: Codable, Equatable {
    let id: String
    let email: String
    let name: String
}

struct LoginResponse: Codable {
    let token: String
    let user: AuthUser
}

struct SSOExchangeRequest: Codable {
    let accessToken: String
}
