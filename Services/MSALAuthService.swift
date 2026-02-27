import Foundation
import MSAL

enum MSALError: Error {
    case msalNotConfigured
    case missingToken
    case unknown
}

class MSALAuthService {
    static let shared = MSALAuthService()

    private var publicClientApplication: MSALPublicClientApplication?

    // TODO: Replace with your actual Azure AD App Client ID and Tenant ID
    private let clientId = "YOUR_CLIENT_ID_HERE"
    private let tenantId = "YOUR_TENANT_ID_HERE"

    // Scopes needed for ZentiOS (Usually User.Read for Microsoft Graph or custom scopes)
    private let scopes = ["User.Read"]

    private init() {
        do {
            guard let authorityURL = URL(string: "https://login.microsoftonline.com/\(tenantId)")
            else {
                return
            }
            let authority = try MSALAADAuthority(url: authorityURL)
            let config = MSALPublicClientApplicationConfig(
                clientId: clientId, redirectUri: nil, authority: authority)
            self.publicClientApplication = try MSALPublicClientApplication(configuration: config)
        } catch {
            print("Failed to initialize MSAL: \(error)")
        }
    }

    /// Present interactive Microsoft Login UI
    func acquireTokenInteractively(with webViewParameters: MSALWebviewParameters) async throws
        -> String
    {
        guard let application = publicClientApplication else {
            throw MSALError.msalNotConfigured
        }

        let parameters = MSALInteractiveTokenParameters(
            scopes: scopes, webviewParameters: webViewParameters)

        return try await withCheckedThrowingContinuation { continuation in
            application.acquireToken(with: parameters) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let token = result?.accessToken else {
                    continuation.resume(throwing: MSALError.missingToken)
                    return
                }

                continuation.resume(returning: token)
            }
        }
    }

    /// Attempt to acquire token silently without showing UI
    func acquireTokenSilently() async throws -> String {
        guard let application = publicClientApplication else {
            throw MSALError.msalNotConfigured
        }

        // Find existing accounts
        let accounts = try application.allAccounts()
        guard let account = accounts.first else {
            throw MSALError.missingToken  // No saved account, interactive login needed
        }

        let parameters = MSALSilentTokenParameters(scopes: scopes, account: account)

        return try await withCheckedThrowingContinuation { continuation in
            application.acquireTokenSilent(with: parameters) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let token = result?.accessToken else {
                    continuation.resume(throwing: MSALError.missingToken)
                    return
                }

                continuation.resume(returning: token)
            }
        }
    }

    /// Sign out locally
    func signOut() throws {
        guard let application = publicClientApplication else { return }
        let accounts = try application.allAccounts()
        for account in accounts {
            try application.remove(account)
        }
    }
}
