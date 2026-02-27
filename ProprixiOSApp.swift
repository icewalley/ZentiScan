
import SwiftUI

@main
struct ZentiChecklistApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var scannedCode: String = ""
    @State private var showScanner = false
    @State private var showSmartScanner = false
    @State private var detectedEquipment: [DetectedEquipment] = []
    @State private var path = NavigationPath()
    @State private var scanMode: ScanMode = .smart
    
    enum ScanMode: String, CaseIterable {
        case smart = "Smart Scan"
        case code = "Kode Scan"
        case manual = "Manuell"
        
        var icon: String {
            switch self {
            case .smart: return "sparkles"
            case .code: return "qrcode.viewfinder"
            case .manual: return "keyboard"
            }
        }
        
        var description: String {
            switch self {
            case .smart: return "AI identifiserer utstyr automatisk"
            case .code: return "Scan QR/strekkode eller TFM-merke"
            case .manual: return "Skriv inn NS3457-kode manuelt"
            }
        }
    }
    
    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 30) {
                    // Header
                    headerSection
                    
                    // Scan Mode Selection
                    scanModeSection
                    
                    // Quick Actions
                    quickActionsSection
                    
                    // Recent Activity (placeholder)
                    recentActivitySection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Zenti Sjekkliste")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: String.self) { code in
                ChecklistView(code: code)
            }
            .navigationDestination(for: DetectedEquipment.self) { equipment in
                EquipmentDetailView(equipment: equipment)
            }
            .sheet(isPresented: $showScanner) {
                ScannerView(scannedText: $scannedCode)
            }
            .fullScreenCover(isPresented: $showSmartScanner) {
                SmartScannerView(detectedEquipment: $detectedEquipment)
            }
            .onChange(of: scannedCode) { _, newValue in
                if !newValue.isEmpty {
                    path.append(newValue)
                }
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
        VStack(spacing: 16) {
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
                    .frame(width: 100, height: 100)
                
                Image(systemName: "checklist")
                    .font(.system(size: 44))
                    .foregroundColor(.white)
            }
            .shadow(color: .blue.opacity(0.3), radius: 15, y: 8)
            
            Text("Vedlikeholdssjekklister")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Bruk kamera for å identifisere utstyr og generere sjekklister automatisk")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top, 20)
    }
    
    private var scanModeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Velg skannemodus")
                .font(.headline)
            
            ForEach(ScanMode.allCases, id: \.self) { mode in
                Button(action: { handleScanMode(mode) }) {
                    HStack(spacing: 16) {
                        Image(systemName: mode.icon)
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(
                                mode == .smart ? 
                                    LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                    LinearGradient(colors: [.blue, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .cornerRadius(12)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(mode.rawValue)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text(mode.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Hurtigvalg")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                quickActionCard(
                    icon: "drop.fill",
                    title: "Pumper",
                    code: "PU",
                    color: .cyan
                )
                
                quickActionCard(
                    icon: "wind",
                    title: "Vifter",
                    code: "VF",
                    color: .blue
                )
                
                quickActionCard(
                    icon: "flame.fill",
                    title: "Brannsikring",
                    code: "SL",
                    color: .red
                )
                
                quickActionCard(
                    icon: "thermometer.medium",
                    title: "Varme",
                    code: "VA",
                    color: .orange
                )
            }
        }
    }
    
    private func quickActionCard(icon: String, title: String, code: String, color: Color) -> some View {
        Button(action: { path.append(code) }) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(code)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(color)
                    .cornerRadius(4)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        }
        .buttonStyle(.plain)
    }
    
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
    
    // MARK: - Manual Code Entry
    
    private var manualEntrySection: some View {
        VStack(spacing: 15) {
            TextField("Skriv inn kode (f.eks. PU)", text: $scannedCode)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .textInputAutocapitalization(.characters)
            
            Button(action: {
                if !scannedCode.isEmpty {
                    path.append(scannedCode)
                }
            }) {
                Text("Gå til sjekkliste")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(scannedCode.isEmpty ? Color.gray : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(scannedCode.isEmpty)
        }
    }
    
    // MARK: - Actions
    
    private func handleScanMode(_ mode: ScanMode) {
        scanMode = mode
        
        switch mode {
        case .smart:
            showSmartScanner = true
        case .code:
            showScanner = true
        case .manual:
            // Show keyboard input
            break
        }
    }
}

// Make DetectedEquipment Hashable for navigation
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
