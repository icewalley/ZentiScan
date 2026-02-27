
import SwiftUI
import Network

/// Network connectivity monitor for offline mode detection
@MainActor
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    @Published var isConnected = true
    @Published var connectionType: ConnectionType = .unknown
    
    enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
    }
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "no.zenti.networkmonitor")
    
    init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
                self?.connectionType = self?.getConnectionType(path) ?? .unknown
            }
        }
        monitor.start(queue: queue)
    }
    
    private func getConnectionType(_ path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        }
        return .unknown
    }
}

/// Offline banner shown when device is offline
struct OfflineBanner: View {
    @ObservedObject var networkMonitor = NetworkMonitor.shared
    @ObservedObject var cacheManager = OfflineCacheManager.shared
    
    var body: some View {
        if !networkMonitor.isConnected {
            HStack(spacing: 12) {
                Image(systemName: "wifi.slash")
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Frakoblet modus")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    if cacheManager.pendingSubmissions > 0 {
                        Text("\(cacheManager.pendingSubmissions) venter på synkronisering")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                Spacer()
                
                if cacheManager.isSyncing {
                    ProgressView()
                        .tint(.white)
                }
            }
            .padding()
            .background(Color.orange)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

/// Sync status indicator for toolbar
struct SyncStatusIndicator: View {
    @ObservedObject var networkMonitor = NetworkMonitor.shared
    @ObservedObject var cacheManager = OfflineCacheManager.shared
    
    var body: some View {
        Button(action: {
            Task { await cacheManager.syncPendingSubmissions() }
        }) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                
                if cacheManager.pendingSubmissions > 0 {
                    Text("\(cacheManager.pendingSubmissions)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Circle().fill(Color.red))
                        .offset(x: 8, y: -8)
                }
            }
        }
        .disabled(!networkMonitor.isConnected || cacheManager.isSyncing)
    }
    
    private var statusIcon: String {
        if cacheManager.isSyncing {
            return "arrow.triangle.2.circlepath"
        } else if !networkMonitor.isConnected {
            return "wifi.slash"
        } else if cacheManager.pendingSubmissions > 0 {
            return "arrow.up.circle"
        } else {
            return "checkmark.icloud"
        }
    }
    
    private var statusColor: Color {
        if !networkMonitor.isConnected {
            return .orange
        } else if cacheManager.pendingSubmissions > 0 {
            return .blue
        } else {
            return .green
        }
    }
}

/// Cached data indicator badge
struct CachedBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.caption2)
            Text("Bufret")
                .font(.caption2)
        }
        .foregroundColor(.green)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.green.opacity(0.1))
        .cornerRadius(4)
    }
}
