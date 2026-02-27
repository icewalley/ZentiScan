
import Foundation
import SwiftData

/// Offline cache manager using SwiftData for persistent storage
@MainActor
class OfflineCacheManager: ObservableObject {
    
    static let shared = OfflineCacheManager()
    
    @Published var isSyncing = false
    @Published var pendingSubmissions: Int = 0
    @Published var lastSyncDate: Date?
    
    private var modelContainer: ModelContainer?
    private var modelContext: ModelContext?
    
    init() {
        setupSwiftData()
    }
    
    private func setupSwiftData() {
        do {
            let schema = Schema([
                CachedChecklist.self,
                CachedCheckpoint.self,
                PendingSubmission.self,
                CachedEquipmentCode.self,
            ])
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            modelContext = modelContainer?.mainContext
            
        } catch {
            print("[OfflineCache] Failed to setup SwiftData: \(error)")
        }
    }
    
    // MARK: - Checklist Caching
    
    /// Cache a checklist for offline access
    func cacheChecklist(_ checkpoints: [Checkpoint], for code: String, aiTips: [String]? = nil) {
        guard let context = modelContext else { return }
        
        // Remove existing cache for this code
        let descriptor = FetchDescriptor<CachedChecklist>(
            predicate: #Predicate { $0.ns3457Code == code }
        )
        
        if let existing = try? context.fetch(descriptor) {
            existing.forEach { context.delete($0) }
        }
        
        // Create new cache entry
        let cached = CachedChecklist(
            ns3457Code: code,
            cachedAt: Date(),
            aiTips: aiTips ?? []
        )
        
        context.insert(cached)
        
        // Cache individual checkpoints
        for checkpoint in checkpoints {
            let cachedCheckpoint = CachedCheckpoint(
                checkpointId: checkpoint.id,
                text: checkpoint.text,
                description: checkpoint.description,
                type: checkpoint.type,
                criticality: checkpoint.criticality,
                ns3457Code: code
            )
            context.insert(cachedCheckpoint)
        }
        
        try? context.save()
    }
    
    /// Get cached checklist for a code
    func getCachedChecklist(for code: String) -> (checkpoints: [Checkpoint], aiTips: [String])? {
        guard let context = modelContext else { return nil }
        
        // Get the cached checklist
        let listDescriptor = FetchDescriptor<CachedChecklist>(
            predicate: #Predicate { $0.ns3457Code == code }
        )
        
        guard let cached = try? context.fetch(listDescriptor).first else { return nil }
        
        // Check if cache is still valid (24 hours)
        let cacheAge = Date().timeIntervalSince(cached.cachedAt)
        guard cacheAge < 86400 else { return nil } // 24 hours
        
        // Get cached checkpoints
        let checkpointDescriptor = FetchDescriptor<CachedCheckpoint>(
            predicate: #Predicate { $0.ns3457Code == code }
        )
        
        guard let cachedCheckpoints = try? context.fetch(checkpointDescriptor) else { return nil }
        
        let checkpoints = cachedCheckpoints.map { cp in
            Checkpoint(
                id: cp.checkpointId,
                text: cp.text,
                description: cp.descriptionText,
                type: cp.type,
                criticality: cp.criticality,
                canFetchAutomatically: nil
            )
        }
        
        return (checkpoints, cached.aiTips)
    }
    
    // MARK: - Pending Submissions
    
    /// Queue a submission for later sync
    func queueSubmission(_ submission: ChecklistSubmission) {
        guard let context = modelContext else { return }
        
        let pending = PendingSubmission(
            ns3457Code: submission.ns3457Code,
            performedBy: submission.performedBy,
            resultsData: encodeResults(submission.results),
            notes: submission.notes,
            queuedAt: Date()
        )
        
        context.insert(pending)
        try? context.save()
        
        updatePendingCount()
    }
    
    /// Get all pending submissions
    func getPendingSubmissions() -> [PendingSubmission] {
        guard let context = modelContext else { return [] }
        
        let descriptor = FetchDescriptor<PendingSubmission>(
            sortBy: [SortDescriptor(\.queuedAt)]
        )
        
        return (try? context.fetch(descriptor)) ?? []
    }
    
    /// Sync pending submissions when online
    func syncPendingSubmissions() async {
        guard !isSyncing else { return }
        
        await MainActor.run { isSyncing = true }
        defer { Task { @MainActor in isSyncing = false } }
        
        let pending = getPendingSubmissions()
        
        for submission in pending {
            do {
                // Recreate submission from cached data
                let results = decodeResults(submission.resultsData)
                
                let checklistSubmission = ChecklistSubmission(
                    ns3457Code: submission.ns3457Code,
                    equipmentId: nil,
                    location: nil,
                    performedBy: submission.performedBy,
                    results: results,
                    photos: nil,
                    notes: submission.notes,
                    completedAt: submission.queuedAt
                )
                
                // Try to submit
                let _ = try await APIManager.shared.submitChecklistResults(checklistSubmission)
                
                // If successful, remove from queue
                guard let context = modelContext else { continue }
                context.delete(submission)
                try? context.save()
                
            } catch {
                print("[OfflineCache] Failed to sync submission: \(error)")
                // Keep in queue for retry
            }
        }
        
        await MainActor.run {
            updatePendingCount()
            lastSyncDate = Date()
        }
    }
    
    // MARK: - Equipment Code Caching
    
    /// Cache equipment codes for offline browsing
    func cacheEquipmentCodes(_ codes: [NS3457CodeInfo]) {
        guard let context = modelContext else { return }
        
        // Clear existing
        let descriptor = FetchDescriptor<CachedEquipmentCode>()
        if let existing = try? context.fetch(descriptor) {
            existing.forEach { context.delete($0) }
        }
        
        // Insert new
        for code in codes {
            let cached = CachedEquipmentCode(
                code: code.code,
                name: code.name,
                category: code.category,
                descriptionText: code.description,
                checkpointCount: code.checkpointCount ?? 0
            )
            context.insert(cached)
        }
        
        try? context.save()
    }
    
    /// Get cached equipment codes
    func getCachedEquipmentCodes() -> [NS3457CodeInfo] {
        guard let context = modelContext else { return [] }
        
        let descriptor = FetchDescriptor<CachedEquipmentCode>(
            sortBy: [SortDescriptor(\.code)]
        )
        
        guard let cached = try? context.fetch(descriptor) else { return [] }
        
        return cached.map { c in
            NS3457CodeInfo(
                code: c.code,
                name: c.name,
                description: c.descriptionText,
                category: c.category,
                checkpointCount: c.checkpointCount
            )
        }
    }
    
    // MARK: - Helpers
    
    private func updatePendingCount() {
        pendingSubmissions = getPendingSubmissions().count
    }
    
    private func encodeResults(_ results: [ChecklistPointResult]) -> Data {
        (try? JSONEncoder().encode(results)) ?? Data()
    }
    
    private func decodeResults(_ data: Data) -> [ChecklistPointResult] {
        (try? JSONDecoder().decode([ChecklistPointResult].self, from: data)) ?? []
    }
}

// MARK: - SwiftData Models

@Model
final class CachedChecklist {
    var ns3457Code: String
    var cachedAt: Date
    var aiTips: [String]
    
    init(ns3457Code: String, cachedAt: Date, aiTips: [String]) {
        self.ns3457Code = ns3457Code
        self.cachedAt = cachedAt
        self.aiTips = aiTips
    }
}

@Model
final class CachedCheckpoint {
    var checkpointId: Int
    var text: String
    var descriptionText: String?
    var type: String
    var criticality: String?
    var ns3457Code: String
    
    init(checkpointId: Int, text: String, description: String?, type: String, criticality: String?, ns3457Code: String) {
        self.checkpointId = checkpointId
        self.text = text
        self.descriptionText = description
        self.type = type
        self.criticality = criticality
        self.ns3457Code = ns3457Code
    }
}

@Model
final class PendingSubmission {
    var ns3457Code: String
    var performedBy: String
    var resultsData: Data
    var notes: String?
    var queuedAt: Date
    
    init(ns3457Code: String, performedBy: String, resultsData: Data, notes: String?, queuedAt: Date) {
        self.ns3457Code = ns3457Code
        self.performedBy = performedBy
        self.resultsData = resultsData
        self.notes = notes
        self.queuedAt = queuedAt
    }
}

@Model
final class CachedEquipmentCode {
    var code: String
    var name: String
    var category: String?
    var descriptionText: String?
    var checkpointCount: Int
    
    init(code: String, name: String, category: String?, descriptionText: String?, checkpointCount: Int) {
        self.code = code
        self.name = name
        self.category = category
        self.descriptionText = descriptionText
        self.checkpointCount = checkpointCount
    }
}
