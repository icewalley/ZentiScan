
import SwiftUI
import AVFoundation

/// Voice input component for hands-free checklist completion
struct VoiceInputView: View {
    @ObservedObject var aiService: AppleIntelligenceService
    @Binding var isPresented: Bool
    
    let onResult: (VoiceInputResult) -> Void
    
    @State private var hasAuthorization = false
    @State private var showingAuthorizationAlert = false
    @State private var pulseAnimation = false
    
    var body: some View {
        VStack(spacing: 30) {
            // Header
            Text("Taleregistrering")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Si status ('OK' eller 'Avvik') eller dikter en kommentar")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
            
            // Microphone Button
            ZStack {
                // Pulse animation when listening
                if aiService.isListening {
                    Circle()
                        .fill(Color.red.opacity(0.3))
                        .frame(width: 160, height: 160)
                        .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                        .opacity(pulseAnimation ? 0.0 : 0.5)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: false), value: pulseAnimation)
                }
                
                Circle()
                    .fill(aiService.isListening ? Color.red : Color.blue)
                    .frame(width: 120, height: 120)
                    .shadow(color: (aiService.isListening ? Color.red : Color.blue).opacity(0.5), radius: 10, y: 5)
                
                Image(systemName: aiService.isListening ? "waveform" : "mic.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
                    .symbolEffect(.variableColor, isActive: aiService.isListening)
            }
            .onTapGesture {
                toggleListening()
            }
            
            // Status Text
            Text(aiService.isListening ? "Lytter..." : "Trykk for å starte")
                .font(.headline)
                .foregroundColor(aiService.isListening ? .red : .secondary)
            
            // Transcribed Text
            if !aiService.transcribedText.isEmpty {
                VStack(spacing: 12) {
                    Text("Gjenkjent tekst:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(aiService.transcribedText)
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Suggestions
            if !aiService.suggestions.isEmpty {
                VStack(spacing: 8) {
                    ForEach(aiService.suggestions, id: \.self) { suggestion in
                        Button(action: { applySuggestion(suggestion) }) {
                            HStack {
                                Image(systemName: suggestionIcon(for: suggestion))
                                    .foregroundColor(.white)
                                Text(suggestion)
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(suggestionColor(for: suggestion))
                            .cornerRadius(10)
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
            
            // Cancel Button
            Button(action: { isPresented = false }) {
                Text("Avbryt")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .padding()
        .onAppear {
            checkAuthorization()
            pulseAnimation = true
        }
        .onDisappear {
            aiService.stopListening()
        }
        .alert("Talegjenkjenning", isPresented: $showingAuthorizationAlert) {
            Button("Åpne Innstillinger") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Avbryt", role: .cancel) {
                isPresented = false
            }
        } message: {
            Text("Appen trenger tilgang til talegjenkjenning. Vennligst aktiver i Innstillinger.")
        }
    }
    
    // MARK: - Actions
    
    private func checkAuthorization() {
        Task {
            hasAuthorization = await aiService.requestSpeechAuthorization()
            if !hasAuthorization {
                showingAuthorizationAlert = true
            }
        }
    }
    
    private func toggleListening() {
        if aiService.isListening {
            aiService.stopListening()
            
            // Process the result
            if !aiService.transcribedText.isEmpty {
                let analysis = aiService.analyzeText(aiService.transcribedText)
                let result = VoiceInputResult(
                    transcription: aiService.transcribedText,
                    status: analysis.suggestedAction == .markAsOK ? .ok :
                            analysis.suggestedAction == .markAsDeviation ? .deviation : nil,
                    measurement: analysis.measurements.first,
                    comment: analysis.statusIndicators.isEmpty ? aiService.transcribedText : nil
                )
                onResult(result)
            }
        } else {
            do {
                try aiService.startListening()
            } catch {
                aiService.errorMessage = error.localizedDescription
            }
        }
    }
    
    private func applySuggestion(_ suggestion: String) {
        if suggestion.contains("OK") {
            onResult(VoiceInputResult(transcription: "OK", status: .ok, measurement: nil, comment: nil))
            isPresented = false
        } else if suggestion.contains("AVVIK") {
            onResult(VoiceInputResult(transcription: "Avvik", status: .deviation, measurement: nil, comment: nil))
            isPresented = false
        } else if suggestion.contains("måling") {
            // Extract measurement from suggestion
            let numbers = suggestion.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            if !numbers.isEmpty {
                onResult(VoiceInputResult(transcription: numbers, status: nil, measurement: numbers, comment: nil))
                isPresented = false
            }
        }
    }
    
    private func suggestionIcon(for suggestion: String) -> String {
        if suggestion.contains("OK") {
            return "checkmark.circle.fill"
        } else if suggestion.contains("AVVIK") {
            return "exclamationmark.triangle.fill"
        } else if suggestion.contains("måling") {
            return "number"
        } else {
            return "arrow.right.circle.fill"
        }
    }
    
    private func suggestionColor(for suggestion: String) -> Color {
        if suggestion.contains("OK") {
            return .green
        } else if suggestion.contains("AVVIK") {
            return .red
        } else {
            return .blue
        }
    }
}

// MARK: - Voice Input Result

struct VoiceInputResult {
    let transcription: String
    let status: CheckpointStatusValue?
    let measurement: String?
    let comment: String?
    
    enum CheckpointStatusValue {
        case ok
        case deviation
        case notAssessed
    }
}

// MARK: - Intelligent Suggestions Card

struct IntelligentSuggestionsCard: View {
    let suggestions: [IntelligentSuggestion]
    let onAction: (SuggestionAction) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                Text("AI-forslag")
                    .font(.headline)
            }
            
            ForEach(suggestions) { suggestion in
                Button(action: { onAction(suggestion.action) }) {
                    HStack {
                        Image(systemName: suggestion.icon)
                            .foregroundColor(.purple)
                            .frame(width: 24)
                        
                        Text(suggestion.text)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if suggestion.action != .none {
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .disabled(suggestion.action == .none)
                
                if suggestion.id != suggestions.last?.id {
                    Divider()
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.purple.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.purple.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Voice Command Overlay

struct VoiceCommandOverlay: View {
    @ObservedObject var aiService: AppleIntelligenceService
    @Binding var isActive: Bool
    
    var body: some View {
        if isActive && aiService.isListening {
            VStack {
                Spacer()
                
                HStack {
                    Image(systemName: "waveform")
                        .foregroundColor(.white)
                        .symbolEffect(.variableColor)
                    
                    Text(aiService.transcribedText.isEmpty ? "Lytter..." : aiService.transcribedText)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Button(action: { 
                        aiService.stopListening()
                        isActive = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding()
                .background(Color.red)
                .cornerRadius(12)
                .padding()
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

#Preview {
    VoiceInputView(
        aiService: AppleIntelligenceService(),
        isPresented: .constant(true)
    ) { result in
        print("Got result: \(result)")
    }
}
