import MSAL
import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager

    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Header
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)

                    Image(systemName: "lock.shield")
                        .font(.system(size: 36))
                        .foregroundColor(.white)
                }
                .shadow(color: .blue.opacity(0.3), radius: 10, y: 5)

                Text("Zenti Sjekkliste")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Logg inn med prosjektkontoen din for tilgang til feltløsningen.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.bottom, 32)

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }

            // Login Button (Microsoft SSO)
            Button(action: handleMSALLogin) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        // Normally you'd use a Microsoft Logo image here
                        Image(systemName: "window.casement")
                        Text("Logg inn med Microsoft")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    Color(
                        uiColor: UIColor(red: 47 / 255, green: 47 / 255, blue: 47 / 255, alpha: 1.0)
                    )
                )  // Microsoft dark gray
                .foregroundColor(.white)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            }
            .disabled(isLoading)
            .padding(.horizontal, 32)

            Spacer()
        }
        .padding(32)
        .background(Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all))
    }

    private func handleMSALLogin() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                // Determine the key window to host the ASWebAuthenticationSession popup
                guard
                    let windowScene = await UIApplication.shared.connectedScenes.first
                        as? UIWindowScene,
                    let window = await windowScene.windows.first(where: { $0.isKeyWindow }),
                    let rootViewController = await window.rootViewController
                else {
                    throw URLError(.cannotFindHostName)
                }

                let webViewParameters = MSALWebviewParameters(
                    authPresentationViewController: rootViewController)

                // 1. Acquire Token via Microsoft Login popup
                let msalToken = try await MSALAuthService.shared.acquireTokenInteractively(
                    with: webViewParameters)

                // 2. Exchange MSAL Token for ZentiOS JWT with our Backend
                try await authManager.exchangeMSALToken(msalToken: msalToken)

                await MainActor.run {
                    isLoading = false
                    // authManager state update will automatically dismiss this view
                }

            } catch let error as MSALError {
                await MainActor.run {
                    if error == .msalNotConfigured {
                        errorMessage = "MSAL er ikke riktig konfigurert."
                    } else {
                        errorMessage = "Innloggingen ble avbrutt."
                    }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Nettverksfeil eller feil ved verifisering. Prøv igjen."
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager.shared)
}
