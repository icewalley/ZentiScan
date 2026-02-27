
import SwiftUI

/// Displays detailed information about detected equipment and offers checklist generation
struct EquipmentDetailView: View {
    let equipment: DetectedEquipment
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var api = APIManager.shared
    
    @State private var isLoadingChecklist = false
    @State private var generatedChecklist: GenerateChecklistResponse?
    @State private var showingChecklist = false
    @State private var locationContext: String = ""
    @State private var additionalNotes: String = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Equipment Header Card
                    equipmentHeader
                    
                    // NS3457 Info
                    ns3457InfoCard
                    
                    // Context Input
                    contextInputSection
                    
                    // AI Tips (if available)
                    if let tips = generatedChecklist?.aiTips, !tips.isEmpty {
                        aiTipsCard(tips: tips)
                    }
                    
                    // Action Buttons
                    actionButtons
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Utstyrsdetaljer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Lukk") { dismiss() }
                }
            }
            .sheet(isPresented: $showingChecklist) {
                if let checklist = generatedChecklist {
                    GeneratedChecklistView(
                        equipment: equipment,
                        checkpoints: checklist.checkpoints,
                        aiTips: checklist.aiTips
                    )
                }
            }
            .onAppear {
                loadChecklistPreview()
            }
        }
    }
    
    // MARK: - View Components
    
    private var equipmentHeader: some View {
        VStack(spacing: 16) {
            // Category Icon
            ZStack {
                Circle()
                    .fill(categoryGradient)
                    .frame(width: 100, height: 100)
                
                Image(systemName: equipment.category.icon)
                    .font(.system(size: 44))
                    .foregroundColor(.white)
            }
            .shadow(color: categoryColor.opacity(0.4), radius: 10, y: 5)
            
            // Equipment Name
            Text(equipment.suggestedName)
                .font(.title)
                .fontWeight(.bold)
            
            // Category Badge
            Text(equipment.category.rawValue)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Confidence Indicator
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(confidenceColor)
                Text("\(Int(equipment.confidence * 100))% sikkerhet")
                    .font(.subheadline)
                    .foregroundColor(confidenceColor)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(confidenceColor.opacity(0.1))
            .cornerRadius(20)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }
    
    private var ns3457InfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("NS 3457-8 Klassifisering", systemImage: "doc.text.magnifyingglass")
                .font(.headline)
                .foregroundColor(.primary)
            
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Komponentkode")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(equipment.ns3457Code)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Kategori")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(equipment.category.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            
            // TFM Code Example
            VStack(alignment: .leading, spacing: 8) {
                Text("Eksempel TFM-kode")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 0) {
                    Text("=360")
                        .foregroundColor(.green)
                    Text(".01")
                        .foregroundColor(.green.opacity(0.7))
                    Text("-")
                        .foregroundColor(.gray)
                    Text(equipment.ns3457Code)
                        .foregroundColor(.blue)
                        .fontWeight(.bold)
                    Text("001")
                        .foregroundColor(.blue.opacity(0.7))
                }
                .font(.system(.body, design: .monospaced))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }
    
    private var contextInputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Kontekst", systemImage: "location.fill")
                .font(.headline)
            
            TextField("Lokasjon (f.eks. Teknisk rom, 2. etasje)", text: $locationContext)
                .textFieldStyle(.roundedBorder)
            
            TextField("Tilleggsnotater", text: $additionalNotes, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...5)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }
    
    private func aiTipsCard(tips: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("AI-anbefalinger", systemImage: "sparkles")
                .font(.headline)
                .foregroundColor(.purple)
            
            Divider()
            
            ForEach(tips, id: \.self) { tip in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                        .frame(width: 24)
                    
                    Text(tip)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.purple.opacity(0.1), Color.purple.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.purple.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Primary Action: Generate Checklist
            Button(action: generateAndShowChecklist) {
                HStack {
                    if isLoadingChecklist {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "checklist")
                    }
                    Text(isLoadingChecklist ? "Genererer..." : "Generer sjekkliste")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(categoryGradient)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isLoadingChecklist)
            
            // Preview: Number of checkpoints
            if let checklist = generatedChecklist {
                HStack {
                    Image(systemName: "info.circle")
                    Text("\(checklist.checkpoints.count) sjekkpunkter tilgjengelig")
                    if let time = checklist.estimatedTimeMinutes {
                        Text("• ~\(time) min")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            // Secondary Action: Manual Entry
            Button(action: { /* Navigate to manual code entry */ }) {
                HStack {
                    Image(systemName: "keyboard")
                    Text("Skriv inn kode manuelt")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray5))
                .foregroundColor(.primary)
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var categoryColor: Color {
        switch equipment.category {
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
    
    private var categoryGradient: LinearGradient {
        LinearGradient(
            colors: [categoryColor, categoryColor.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var confidenceColor: Color {
        if equipment.confidence >= 0.8 {
            return .green
        } else if equipment.confidence >= 0.5 {
            return .orange
        } else {
            return .red
        }
    }
    
    // MARK: - Actions
    
    private func loadChecklistPreview() {
        Task {
            do {
                generatedChecklist = try await api.generateChecklist(
                    for: equipment.ns3457Code,
                    context: nil,
                    location: nil
                )
            } catch {
                print("Failed to load checklist preview: \(error)")
            }
        }
    }
    
    private func generateAndShowChecklist() {
        isLoadingChecklist = true
        
        Task {
            do {
                generatedChecklist = try await api.generateChecklist(
                    for: equipment.ns3457Code,
                    context: additionalNotes.isEmpty ? nil : additionalNotes,
                    location: locationContext.isEmpty ? nil : locationContext
                )
                showingChecklist = true
            } catch {
                print("Failed to generate checklist: \(error)")
            }
            
            isLoadingChecklist = false
        }
    }
}

#Preview {
    EquipmentDetailView(
        equipment: DetectedEquipment(
            ns3457Code: "PU",
            confidence: 0.92,
            boundingBox: .zero,
            suggestedName: "Sirkulasjonspumpe",
            category: .plumbing
        )
    )
}
