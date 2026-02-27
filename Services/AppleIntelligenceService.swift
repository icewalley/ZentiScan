
import Foundation
import Speech
import NaturalLanguage

/// Service for Apple Intelligence features including speech recognition and natural language processing
@MainActor
class AppleIntelligenceService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isListening = false
    @Published var transcribedText = ""
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var suggestions: [String] = []
    
    // MARK: - Private Properties
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // Natural Language Processing
    private let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType, .lemma])
    
    // Equipment-related keywords for context understanding
    private let equipmentKeywords = Set([
        "pumpe", "vifte", "ventil", "motor", "sensor", "filter",
        "radiator", "kjølemaskin", "kompressor", "brannslukker",
        "lekkasje", "trykk", "temperatur", "lyd", "vibrasjon",
        "avvik", "ok", "godkjent", "feiler", "defekt"
    ])
    
    // MARK: - Initialization
    
    init() {
        setupSpeechRecognizer()
    }
    
    private func setupSpeechRecognizer() {
        // Norwegian speech recognizer
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "nb-NO"))
        
        // Fallback to English if Norwegian not available
        if speechRecognizer == nil || !speechRecognizer!.isAvailable {
            speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        }
    }
    
    // MARK: - Speech Recognition
    
    /// Request speech recognition authorization
    func requestSpeechAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
    
    /// Start listening for voice input
    func startListening() throws {
        // Cancel any ongoing recognition
        stopListening()
        
        // Check authorization
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw AIError.notAuthorized
        }
        
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw AIError.recognizerNotAvailable
        }
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.shouldReportPartialResults = true
        recognitionRequest?.requiresOnDeviceRecognition = false // Use server for better accuracy
        
        // Get input node
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Install tap on input
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        // Start recognition task
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest!) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                Task { @MainActor in
                    self.transcribedText = result.bestTranscription.formattedString
                    
                    // Process for equipment-related commands
                    if result.isFinal {
                        self.processVoiceCommand(result.bestTranscription.formattedString)
                    }
                }
            }
            
            if error != nil || result?.isFinal == true {
                Task { @MainActor in
                    self.stopListening()
                }
            }
        }
        
        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()
        
        isListening = true
    }
    
    /// Stop listening for voice input
    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
    }
    
    // MARK: - Voice Command Processing
    
    /// Process a voice command and extract intent
    private func processVoiceCommand(_ text: String) {
        let lowercaseText = text.lowercased()
        
        // Check for status commands
        if lowercaseText.contains("ok") || lowercaseText.contains("godkjent") {
            suggestions = ["Sett status til OK"]
        } else if lowercaseText.contains("avvik") || lowercaseText.contains("feil") {
            suggestions = ["Sett status til AVVIK", "Legg til kommentar om avviket"]
        } else if lowercaseText.contains("neste") {
            suggestions = ["Gå til neste sjekkpunkt"]
        } else if lowercaseText.contains("hopp over") || lowercaseText.contains("ikke vurdert") {
            suggestions = ["Sett status til IKKE VURDERT"]
        }
        
        // Extract any numerical values for measurements
        let numbers = extractNumbers(from: text)
        if !numbers.isEmpty {
            suggestions.append("Registrer måling: \(numbers.first!)")
        }
    }
    
    /// Extract numerical values from text
    private func extractNumbers(from text: String) -> [Double] {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue)
        var numbers: [Double] = []
        
        // Simple number extraction
        let pattern = #"(\d+[,.]?\d*)"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches {
                if let range = Range(match.range, in: text) {
                    let numberString = text[range].replacingOccurrences(of: ",", with: ".")
                    if let number = Double(numberString) {
                        numbers.append(number)
                    }
                }
            }
        }
        
        return numbers
    }
    
    // MARK: - Natural Language Processing
    
    /// Analyze text and extract equipment-related entities
    func analyzeText(_ text: String) -> TextAnalysisResult {
        tagger.string = text
        
        var equipmentMentions: [String] = []
        var statusIndicators: [String] = []
        var measurements: [String] = []
        
        let range = text.startIndex..<text.endIndex
        
        tagger.enumerateTags(in: range, unit: .word, scheme: .lexicalClass) { tag, tokenRange in
            let word = String(text[tokenRange]).lowercased()
            
            if equipmentKeywords.contains(word) {
                equipmentMentions.append(word)
            }
            
            if ["ok", "bra", "fint", "godkjent"].contains(word) {
                statusIndicators.append("positive")
            } else if ["avvik", "feil", "problem", "defekt", "ødelagt"].contains(word) {
                statusIndicators.append("negative")
            }
            
            return true
        }
        
        // Extract measurements
        measurements = extractNumbers(from: text).map { String($0) }
        
        return TextAnalysisResult(
            equipmentMentions: equipmentMentions,
            statusIndicators: statusIndicators,
            measurements: measurements,
            suggestedAction: determineSuggestedAction(statusIndicators: statusIndicators)
        )
    }
    
    private func determineSuggestedAction(statusIndicators: [String]) -> SuggestedAction? {
        if statusIndicators.contains("negative") {
            return .markAsDeviation
        } else if statusIndicators.contains("positive") {
            return .markAsOK
        }
        return nil
    }
    
    // MARK: - Intelligent Suggestions
    
    /// Generate context-aware suggestions based on current state
    func generateSuggestions(
        for checkpoint: Checkpoint,
        equipment: DetectedEquipment,
        previousResults: [Int: String]
    ) -> [IntelligentSuggestion] {
        var suggestions: [IntelligentSuggestion] = []
        
        // Type-specific suggestions
        switch checkpoint.type {
        case "Måling":
            suggestions.append(IntelligentSuggestion(
                text: "Bruk stemme for å registrere måling",
                icon: "mic.fill",
                action: .startVoiceInput
            ))
            
        case "Inspeksjon":
            suggestions.append(IntelligentSuggestion(
                text: "Ta bilde for dokumentasjon",
                icon: "camera.fill",
                action: .takePhoto
            ))
            
        case "Sjekk":
            suggestions.append(IntelligentSuggestion(
                text: "Si 'OK' eller 'Avvik'",
                icon: "waveform",
                action: .startVoiceInput
            ))
            
        default:
            break
        }
        
        // Criticality-based suggestions
        if checkpoint.criticality == "Høy" {
            suggestions.append(IntelligentSuggestion(
                text: "⚠️ Kritisk sjekkpunkt - dokumenter grundig",
                icon: "exclamationmark.triangle.fill",
                action: .none
            ))
        }
        
        // Equipment-specific suggestions
        switch equipment.ns3457Code {
        case "PU":
            suggestions.append(IntelligentSuggestion(
                text: "Tips: Lytt etter kavitasjonslyder",
                icon: "ear.fill",
                action: .none
            ))
        case "VF":
            suggestions.append(IntelligentSuggestion(
                text: "Tips: Sjekk reimspenning",
                icon: "gearshape.fill",
                action: .none
            ))
        case "SL":
            suggestions.append(IntelligentSuggestion(
                text: "Tips: Verifiser at plomben er intakt",
                icon: "seal.fill",
                action: .none
            ))
        default:
            break
        }
        
        return suggestions
    }
    
    // MARK: - Text-to-Speech (Accessibility)
    
    /// Speak text aloud for accessibility
    func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "nb-NO")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        
        let synthesizer = AVSpeechSynthesizer()
        synthesizer.speak(utterance)
    }
}

// MARK: - Supporting Types

struct TextAnalysisResult {
    let equipmentMentions: [String]
    let statusIndicators: [String]
    let measurements: [String]
    let suggestedAction: SuggestedAction?
}

enum SuggestedAction {
    case markAsOK
    case markAsDeviation
    case skipCheckpoint
    case addComment
}

struct IntelligentSuggestion: Identifiable {
    let id = UUID()
    let text: String
    let icon: String
    let action: SuggestionAction
}

enum SuggestionAction {
    case none
    case startVoiceInput
    case takePhoto
    case showHelp
}

enum AIError: LocalizedError {
    case notAuthorized
    case recognizerNotAvailable
    case processingFailed
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Talegjenkjenning er ikke autorisert. Vennligst aktiver i Innstillinger."
        case .recognizerNotAvailable:
            return "Talegjenkjenning er ikke tilgjengelig på denne enheten."
        case .processingFailed:
            return "Kunne ikke behandle talekommandoen."
        }
    }
}



// MARK: - iOS 18+ Apple Intelligence Features

#if swift(>=6.0)
import Foundation

/// Extended Apple Intelligence features for iOS 18+
@available(iOS 18.0, *)
extension AppleIntelligenceService {
    
    /// Use on-device LLM for intelligent responses (iOS 18+)
    func generateIntelligentResponse(for context: String) async -> String? {
        // This would use the new Foundation Models framework in iOS 18
        // For now, return a placeholder
        return nil
    }
    
    /// Summarize maintenance history using Apple Intelligence
    func summarizeMaintenanceHistory(_ history: [String]) async -> String? {
        // Would use iOS 18 summarization APIs
        return nil
    }
}
#endif
