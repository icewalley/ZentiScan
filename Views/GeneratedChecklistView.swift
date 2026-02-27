
import SwiftUI

/// View for completing a dynamically generated checklist
struct GeneratedChecklistView: View {
    let equipment: DetectedEquipment
    let checkpoints: [Checkpoint]
    let aiTips: [String]?
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var api = APIManager.shared
    @StateObject private var aiService = AppleIntelligenceService()
    
    // Checklist State
    @State private var statuses: [Int: CheckpointStatus] = [:]
    @State private var values: [Int: String] = [:]
    @State private var comments: [Int: String] = [:]
    @State private var photos: [Int: [UIImage]] = [:]
    
    // UI State
    @State private var isSubmitting = false
    @State private var showingCamera = false
    @State private var currentPhotoCheckpointId: Int?
    @State private var showingCompletionAlert = false
    @State private var completionMessage = ""
    
    // Voice Input State
    @State private var showingVoiceInput = false
    @State private var currentVoiceCheckpointId: Int?
    @State private var intelligentSuggestions: [IntelligentSuggestion] = []
    
    enum CheckpointStatus: String, CaseIterable {
        case ok = "OK"
        case deviation = "AVVIK"
        case notAssessed = "IKKE VURDERT"
        
        var color: Color {
            switch self {
            case .ok: return .green
            case .deviation: return .red
            case .notAssessed: return .gray
            }
        }
        
        var icon: String {
            switch self {
            case .ok: return "checkmark.circle.fill"
            case .deviation: return "exclamationmark.triangle.fill"
            case .notAssessed: return "questionmark.circle.fill"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Header Section
                Section {
                    equipmentSummary
                }
                
                // AI Tips (collapsed by default)
                if let tips = aiTips, !tips.isEmpty {
                    Section {
                        DisclosureGroup {
                            ForEach(tips, id: \.self) { tip in
                                Label(tip, systemImage: "lightbulb.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        } label: {
                            Label("AI-tips (\(tips.count))", systemImage: "sparkles")
                                .foregroundColor(.purple)
                        }
                    }
                }
                
                // Checkpoints
                Section("Sjekkpunkter (\(checkpoints.count))") {
                    ForEach(checkpoints) { checkpoint in
                        checkpointRow(checkpoint)
                    }
                }
                
                // Summary
                Section {
                    progressSummary
                }
            }
            .navigationTitle("Sjekkliste")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("Send inn") {
                        submitChecklist()
                    }
                    .fontWeight(.semibold)
                    .disabled(isSubmitting || !canSubmit)
                }
                
                // Voice Input Button
                ToolbarItem(placement: .bottomBar) {
                    Button(action: { showingVoiceInput = true }) {
                        Label("Stemmeregistrering", systemImage: "mic.fill")
                    }
                    .tint(.purple)
                }
            }
            .alert("Registrering fullført", isPresented: $showingCompletionAlert) {
                Button("OK") { dismiss() }
            } message: {
                Text(completionMessage)
            }
            .sheet(isPresented: $showingVoiceInput) {
                VoiceInputView(aiService: aiService, isPresented: $showingVoiceInput) { result in
                    handleVoiceResult(result)
                }
                .presentationDetents([.medium, .large])
            }
            // Voice command overlay when actively listening
            .overlay {
                VoiceCommandOverlay(aiService: aiService, isActive: $showingVoiceInput)
            }
        }
    }
    
    // MARK: - View Components
    
    private var equipmentSummary: some View {
        HStack(spacing: 16) {
            Image(systemName: equipment.category.icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(categoryColor(for: equipment.category))
                .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(equipment.suggestedName)
                    .font(.headline)
                
                HStack {
                    Text(equipment.ns3457Code)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue)
                        .cornerRadius(4)
                    
                    Text(equipment.category.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
    }
    
    private func checkpointRow(_ checkpoint: Checkpoint) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Checkpoint Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(checkpoint.text)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if let description = checkpoint.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Criticality Badge
                    if let criticality = checkpoint.criticality {
                        HStack(spacing: 4) {
                            Image(systemName: criticalityIcon(for: criticality))
                            Text(criticality)
                        }
                        .font(.caption2)
                        .foregroundColor(criticalityColor(for: criticality))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(criticalityColor(for: criticality).opacity(0.1))
                        .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                // Status Icon
                if let status = statuses[checkpoint.id] {
                    Image(systemName: status.icon)
                        .foregroundColor(status.color)
                        .font(.title3)
                }
            }
            
            // Status Picker
            Picker("Status", selection: statusBinding(for: checkpoint.id)) {
                ForEach(CheckpointStatus.allCases, id: \.self) { status in
                    Text(status.rawValue).tag(status)
                }
            }
            .pickerStyle(.segmented)
            
            // Value Input (for measurement types)
            if checkpoint.type == "Måling" {
                HStack {
                    TextField("Verdi", text: valueBinding(for: checkpoint.id))
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.decimalPad)
                    
                    // Show expected range if available
                    // This would come from the checkpoint definition
                }
            }
            
            // Comment Input
            TextField("Kommentar (valgfritt)", text: commentBinding(for: checkpoint.id))
                .textFieldStyle(.roundedBorder)
                .font(.caption)
            
            // Photo Attachment
            HStack {
                if let checkpointPhotos = photos[checkpoint.id], !checkpointPhotos.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(checkpointPhotos.indices, id: \.self) { index in
                                Image(uiImage: checkpointPhotos[index])
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 60, height: 60)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                
                Button(action: {
                    currentPhotoCheckpointId = checkpoint.id
                    showingCamera = true
                }) {
                    Label("Foto", systemImage: "camera")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
            
            // Deviation indicator
            if statuses[checkpoint.id] == .deviation {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("Avvik krever dokumentasjon")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(8)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(.vertical, 8)
    }
    
    private var progressSummary: some View {
        VStack(spacing: 12) {
            // Progress Bar
            HStack {
                Text("Fremdrift")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(completedCount)/\(checkpoints.count)")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            ProgressView(value: Double(completedCount), total: Double(checkpoints.count))
                .tint(.green)
            
            // Status Summary
            HStack(spacing: 20) {
                statusCount(for: .ok, label: "OK")
                statusCount(for: .deviation, label: "Avvik")
                statusCount(for: .notAssessed, label: "Ikke vurdert")
            }
            .font(.caption)
        }
    }
    
    private func statusCount(for status: CheckpointStatus, label: String) -> some View {
        let count = statuses.values.filter { $0 == status }.count
        return HStack(spacing: 4) {
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
            Text("\(count) \(label)")
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Bindings
    
    private func statusBinding(for id: Int) -> Binding<CheckpointStatus> {
        Binding(
            get: { statuses[id] ?? .notAssessed },
            set: { statuses[id] = $0 }
        )
    }
    
    private func valueBinding(for id: Int) -> Binding<String> {
        Binding(
            get: { values[id] ?? "" },
            set: { values[id] = $0 }
        )
    }
    
    private func commentBinding(for id: Int) -> Binding<String> {
        Binding(
            get: { comments[id] ?? "" },
            set: { comments[id] = $0 }
        )
    }
    
    // MARK: - Computed Properties
    
    private var completedCount: Int {
        statuses.values.filter { $0 != .notAssessed }.count
    }
    
    private var canSubmit: Bool {
        // At least one checkpoint must be assessed
        completedCount > 0
    }
    
    // MARK: - Actions
    
    private func submitChecklist() {
        isSubmitting = true
        
        Task {
            let results = checkpoints.map { checkpoint in
                ChecklistPointResult(
                    sjekkpunktId: checkpoint.id,
                    oppgaveTekst: checkpoint.text,
                    type: checkpoint.type,
                    value: values[checkpoint.id],
                    status: statuses[checkpoint.id]?.rawValue ?? "IKKE VURDERT",
                    comment: comments[checkpoint.id]
                )
            }
            
            let submission = ChecklistSubmission(
                ns3457Code: equipment.ns3457Code,
                equipmentId: nil,
                location: nil,
                performedBy: "iOS App Bruker",
                results: results,
                photos: nil, // Would encode photos here
                notes: nil,
                completedAt: Date()
            )
            
            do {
                let result = try await api.submitChecklistResults(submission)
                
                await MainActor.run {
                    if result.success {
                        completionMessage = "Sjekklisten er registrert.\n\(completedCount) sjekkpunkter fullført."
                        if let deviations = statuses.values.filter({ $0 == .deviation }).count as Int?,
                           deviations > 0 {
                            completionMessage += "\n\n⚠️ \(deviations) avvik registrert."
                        }
                    } else {
                        completionMessage = result.message ?? "Registrering fullført"
                    }
                    showingCompletionAlert = true
                    isSubmitting = false
                }
            } catch {
                await MainActor.run {
                    completionMessage = "Feil ved lagring: \(error.localizedDescription)"
                    showingCompletionAlert = true
                    isSubmitting = false
                }
            }
        }
    }
    
    /// Handle the result from voice input
    private func handleVoiceResult(_ result: VoiceInputResult) {
        // Determine which checkpoint to update
        // If we have a selected checkpoint, use that; otherwise, find first non-assessed
        let targetCheckpointId = currentVoiceCheckpointId ?? 
            checkpoints.first { statuses[$0.id] == nil || statuses[$0.id] == .notAssessed }?.id
        
        guard let checkpointId = targetCheckpointId else { return }
        
        // Apply status if detected
        if let status = result.status {
            switch status {
            case .ok:
                statuses[checkpointId] = .ok
            case .deviation:
                statuses[checkpointId] = .deviation
            case .notAssessed:
                statuses[checkpointId] = .notAssessed
            }
        }
        
        // Apply measurement if detected
        if let measurement = result.measurement {
            values[checkpointId] = measurement
        }
        
        // Apply comment if it's a freeform response
        if let comment = result.comment, !comment.isEmpty {
            comments[checkpointId] = comment
        }
        
        // Auto-advance to next checkpoint if status was set
        if result.status != nil {
            currentVoiceCheckpointId = findNextUnassessedCheckpoint(after: checkpointId)
            
            // Speak confirmation for accessibility
            if result.status == .ok {
                aiService.speak("Registrert OK")
            } else if result.status == .deviation {
                aiService.speak("Avvik registrert")
            }
        }
        
        showingVoiceInput = false
    }
    
    /// Find the next unassessed checkpoint after the given ID
    private func findNextUnassessedCheckpoint(after currentId: Int) -> Int? {
        var foundCurrent = false
        
        for checkpoint in checkpoints {
            if foundCurrent {
                if statuses[checkpoint.id] == nil || statuses[checkpoint.id] == .notAssessed {
                    return checkpoint.id
                }
            }
            if checkpoint.id == currentId {
                foundCurrent = true
            }
        }
        
        return nil
    }
    
    // MARK: - Helper Functions
    
    private func categoryColor(for category: EquipmentCategory) -> Color {
        switch category {
        case .hvac: return .blue
        case .plumbing: return .cyan
        case .electrical: return .yellow
        case .fire: return .red
        case .access: return .green
        case .heating: return .orange
        case .cooling: return .indigo
        case .control: return .purple
        case .other: return .gray
        }
    }
    
    private func criticalityIcon(for criticality: String) -> String {
        switch criticality.lowercased() {
        case "høy": return "exclamationmark.3"
        case "middels": return "exclamationmark.2"
        case "lav": return "exclamationmark"
        default: return "info.circle"
        }
    }
    
    private func criticalityColor(for criticality: String) -> Color {
        switch criticality.lowercased() {
        case "høy": return .red
        case "middels": return .orange
        case "lav": return .yellow
        default: return .gray
        }
    }
}

#Preview {
    GeneratedChecklistView(
        equipment: DetectedEquipment(
            ns3457Code: "PU",
            confidence: 0.92,
            boundingBox: .zero,
            suggestedName: "Sirkulasjonspumpe",
            category: .plumbing
        ),
        checkpoints: [
            Checkpoint(
                id: 1,
                text: "Kontroller pumpelyd",
                description: "Lytt etter unormale lyder fra pumpen",
                type: "Sjekk",
                criticality: "Høy",
                canFetchAutomatically: false
            ),
            Checkpoint(
                id: 2,
                text: "Mål driftstrykk",
                description: nil,
                type: "Måling",
                criticality: "Middels",
                canFetchAutomatically: true
            )
        ],
        aiTips: [
            "Sjekk tetninger rundt pakningene for lekkasje",
            "Kontroller at pumpen ikke vibrerer unormalt"
        ]
    )
}
