// Make DetectedEquipment Hashable for navigation

import SwiftUI

@main
struct ZentiChecklistApp: App {
    @StateObject private var authManager = AuthManager.shared

    var body: some Scene {
        WindowGroup {
            if authManager.isCheckingAuth {
                ProgressView("Forbereder ZentiScan...")
            } else if authManager.isAuthenticated {
                ContentView()
                    .environmentObject(authManager)
            } else {
                LoginView()
                    .environmentObject(authManager)
            }
        }
    }
}
struct ContentView: View {
    @State private var scannedCode: String = ""
    @State private var showSmartScanner = false
    @State private var detectedEquipment: [DetectedEquipment] = []
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Direct Manual Entry (Sleek Search Bar)
                    manualEntrySection

                    // Main Action (Start Skanning)
                    mainActionSection

                    // Quick Actions
                    quickActionsSection

                    // CMMS: Dagens Oppgaver
                    MyJobsView(path: $path)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Zenti Sjekkliste")
            .navigationBarHidden(true)  // Hide navigation bar to save vertical space
            .navigationDestination(for: String.self) { code in
                ChecklistView(code: code)
            }
            .navigationDestination(for: Vedlikeholdsjobb.self) { job in
                JobExecutionView(job: job)
            }
            .navigationDestination(for: DetectedEquipment.self) { equipment in
                EquipmentDetailView(equipment: equipment)
            }
            .fullScreenCover(isPresented: $showSmartScanner) {
                SmartScannerView(detectedEquipment: $detectedEquipment) { code in
                    path.append(code)
                }
            }
            .onChange(of: scannedCode) { _, newValue in
                // We don't automatically navigate here anymore to allow typing
            }
            .onChange(of: detectedEquipment) { _, newValue in
                if let first = newValue.first {
                    path.append(first)
                }
            }
        }
    }

    // MARK: - View Components

    private var headerSection: some View {
        VStack(spacing: 8) {
            // App Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)

                Image(systemName: "checklist")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
            }
            .shadow(color: .blue.opacity(0.3), radius: 10, y: 5)

            Text("Vedlikeholdssjekklister")
                .font(.title3)
                .fontWeight(.bold)
        }
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    private var manualEntrySection: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Søk etter utstyrskode (f.eks. PU)", text: $scannedCode)
                .textInputAutocapitalization(.characters)
                .submitLabel(.search)
                .onSubmit {
                    if !scannedCode.isEmpty {
                        path.append(scannedCode)
                    }
                }

            if !scannedCode.isEmpty {
                Button(action: { scannedCode = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    private var mainActionSection: some View {
        Button(action: { showSmartScanner = true }) {
            HStack {
                Image(systemName: "camera.viewfinder")
                    .font(.title2)
                Text("Start Skanning")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .foregroundColor(.white)
            .cornerRadius(16)
            .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
        }
        .padding(.vertical, 4)
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hurtigvalg")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    quickActionCard(icon: "drop.fill", title: "Pumper", code: "PU", color: .cyan)
                    quickActionCard(icon: "wind", title: "Vifter", code: "VF", color: .blue)
                    quickActionCard(
                        icon: "flame.fill", title: "Brannsikring", code: "SL", color: .red)
                    quickActionCard(
                        icon: "thermometer.medium", title: "Varme", code: "VA", color: .orange)
                }
            }
        }
    }

    private func quickActionCard(icon: String, title: String, code: String, color: Color)
        -> some View
    {
        Button(action: { path.append(code) }) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Text(code)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color)
                    .cornerRadius(6)
            }
            .frame(width: 110)
            .padding(.vertical, 14)
            .background(Color(.systemBackground))
            .cornerRadius(14)
            .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Manual Code Entry
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Siste aktivitet")
                    .font(.headline)

                Spacer()

                Button("Se alle") {
                    // Navigate to history
                }
                .font(.subheadline)
            }

            // Placeholder for recent activity
            VStack(spacing: 8) {
                ForEach(0..<3) { index in
                    HStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 10, height: 10)

                        VStack(alignment: .leading) {
                            Text("Pumpe PU-\(String(format: "%03d", index + 1))")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Text("\(3 - index) timer siden")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                }
            }
        }
    }

    // MARK: - MyJobsView Integration
    private var myJobsSection: some View {
        MyJobsView(path: $path)
    }
}
extension DetectedEquipment: Hashable {
    static func == (lhs: DetectedEquipment, rhs: DetectedEquipment) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
#Preview {
    ContentView()
}
