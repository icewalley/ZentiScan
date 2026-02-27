
import Foundation
import Vision
import UIKit
import CoreImage

/// Service for detecting equipment in camera frames using Vision framework
@MainActor
class ObjectDetectionService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var detectedEquipment: [DetectedEquipment] = []
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var lastProcessingTime: TimeInterval = 0
    
    // MARK: - Private Properties
    
    private var classificationRequest: VNCoreMLRequest?
    private var objectDetectionRequest: VNRecognizeTextRequest?
    private let processingQueue = DispatchQueue(label: "no.zenti.objectdetection", qos: .userInitiated)
    
    /// Confidence threshold for accepting detections
    private let confidenceThreshold: Float = 0.5
    
    // MARK: - Initialization
    
    init() {
        setupVisionRequests()
    }
    
    // MARK: - Setup
    
    private func setupVisionRequests() {
        // Setup text recognition for reading labels/tags on equipment
        objectDetectionRequest = VNRecognizeTextRequest { [weak self] request, error in
            self?.handleTextRecognition(request: request, error: error)
        }
        objectDetectionRequest?.recognitionLevel = .accurate
        objectDetectionRequest?.recognitionLanguages = ["nb-NO", "en-US"]
        objectDetectionRequest?.usesLanguageCorrection = true
        
        // Note: For full object detection, you would load a Core ML model here
        // setupCoreMLModel()
    }
    
    /// Setup Core ML model for equipment classification (optional enhancement)
    private func setupCoreMLModel() {
        // This would load a custom trained model for equipment detection
        // For now, we use Vision's built-in capabilities + server-side AI
        
        /*
        guard let modelURL = Bundle.main.url(forResource: "EquipmentDetector", withExtension: "mlmodelc"),
              let model = try? VNCoreMLModel(for: MLModel(contentsOf: modelURL)) else {
            print("Failed to load Core ML model")
            return
        }
        
        classificationRequest = VNCoreMLRequest(model: model) { [weak self] request, error in
            self?.handleClassification(request: request, error: error)
        }
        classificationRequest?.imageCropAndScaleOption = .centerCrop
        */
    }
    
    // MARK: - Public Methods
    
    /// Process a camera frame for equipment detection
    func processFrame(_ pixelBuffer: CVPixelBuffer) {
        guard !isProcessing else { return }
        
        isProcessing = true
        let startTime = CFAbsoluteTimeGetCurrent()
        
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            
            do {
                var requests: [VNRequest] = []
                
                // Add text recognition
                if let textRequest = self.objectDetectionRequest {
                    requests.append(textRequest)
                }
                
                // Add rectangle detection for equipment panels/tags
                let rectangleRequest = VNDetectRectanglesRequest { request, error in
                    self.handleRectangleDetection(request: request, error: error)
                }
                rectangleRequest.minimumAspectRatio = 0.3
                rectangleRequest.maximumAspectRatio = 1.0
                rectangleRequest.minimumSize = 0.1
                rectangleRequest.maximumObservations = 10
                requests.append(rectangleRequest)
                
                // Add object classification if model is loaded
                if let classRequest = self.classificationRequest {
                    requests.append(classRequest)
                }
                
                try handler.perform(requests)
                
                let processingTime = CFAbsoluteTimeGetCurrent() - startTime
                
                DispatchQueue.main.async {
                    self.lastProcessingTime = processingTime
                    self.isProcessing = false
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Deteksjonsfeil: \(error.localizedDescription)"
                    self.isProcessing = false
                }
            }
        }
    }
    
    /// Process a UIImage for equipment detection
    func processImage(_ image: UIImage) async throws -> [DetectedEquipment] {
        guard let cgImage = image.cgImage else {
            throw DetectionError.invalidImage
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        var results: [DetectedEquipment] = []
        
        // Text recognition for equipment labels
        let textRequest = VNRecognizeTextRequest()
        textRequest.recognitionLevel = .accurate
        textRequest.recognitionLanguages = ["nb-NO", "en-US"]
        
        // Object classification using built-in classifiers
        let classifyRequest = VNClassifyImageRequest()
        
        try handler.perform([textRequest, classifyRequest])
        
        // Process text results
        if let textObservations = textRequest.results {
            for observation in textObservations {
                guard let candidate = observation.topCandidates(1).first,
                      candidate.confidence > confidenceThreshold else { continue }
                
                let text = candidate.string
                
                // Check if text matches known equipment codes or labels
                if let equipment = parseEquipmentFromText(text, boundingBox: observation.boundingBox) {
                    results.append(equipment)
                }
            }
        }
        
        // Process classification results
        if let classificationObservations = classifyRequest.results {
            for observation in classificationObservations.prefix(5) {
                guard observation.confidence > confidenceThreshold else { continue }
                
                if let equipment = mapClassificationToEquipment(observation) {
                    results.append(equipment)
                }
            }
        }
        
        await MainActor.run {
            self.detectedEquipment = results
        }
        
        return results
    }
    
    /// Analyze an image and return equipment suggestions using server-side AI
    func analyzeWithAI(_ image: UIImage) async throws -> DetectionResponse {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw DetectionError.invalidImage
        }
        
        let base64Image = imageData.base64EncodedString()
        
        let request = DetectionRequest(
            imageBase64: base64Image,
            deviceInfo: DeviceInfo(
                model: UIDevice.current.model,
                osVersion: UIDevice.current.systemVersion,
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
            )
        )
        
        return try await APIManager.shared.detectEquipment(request: request)
    }
    
    // MARK: - Private Handlers
    
    private func handleTextRecognition(request: VNRequest, error: Error?) {
        guard error == nil,
              let observations = request.results as? [VNRecognizedTextObservation] else {
            return
        }
        
        var newEquipment: [DetectedEquipment] = []
        
        for observation in observations {
            guard let candidate = observation.topCandidates(1).first,
                  candidate.confidence > confidenceThreshold else { continue }
            
            if let equipment = parseEquipmentFromText(candidate.string, boundingBox: observation.boundingBox) {
                newEquipment.append(equipment)
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.detectedEquipment = newEquipment
        }
    }
    
    private func handleRectangleDetection(request: VNRequest, error: Error?) {
        // Rectangle detection can help identify equipment panels and tags
        guard error == nil,
              let observations = request.results as? [VNRectangleObservation] else {
            return
        }
        
        // Process rectangles that might be equipment labels
        for observation in observations where observation.confidence > 0.8 {
            // Could trigger focused analysis on these regions
            print("Found rectangle with confidence: \(observation.confidence)")
        }
    }
    
    private func handleClassification(request: VNRequest, error: Error?) {
        guard error == nil,
              let observations = request.results as? [VNClassificationObservation] else {
            return
        }
        
        var newEquipment: [DetectedEquipment] = []
        
        for observation in observations.prefix(3) where observation.confidence > confidenceThreshold {
            if let equipment = mapClassificationToEquipment(observation) {
                newEquipment.append(equipment)
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            // Merge with existing detections
            let existingCodes = Set(self?.detectedEquipment.map { $0.ns3457Code } ?? [])
            let unique = newEquipment.filter { !existingCodes.contains($0.ns3457Code) }
            self?.detectedEquipment.append(contentsOf: unique)
        }
    }
    
    // MARK: - Parsing & Mapping
    
    /// Parse equipment information from recognized text
    private func parseEquipmentFromText(_ text: String, boundingBox: CGRect) -> DetectedEquipment? {
        let upperText = text.uppercased()
        
        // Check for TFM-style codes (e.g., "=360.01-PU001")
        if let tfmMatch = parseTFMCode(upperText) {
            return DetectedEquipment(
                ns3457Code: tfmMatch.code,
                confidence: 0.9,
                boundingBox: boundingBox,
                suggestedName: tfmMatch.name,
                category: tfmMatch.category
            )
        }
        
        // Check for NS3457 Part 8 codes directly (e.g., "PU", "VF", "SE")
        if let codeMatch = NS3457CodeMapping.findCode(for: text) {
            return DetectedEquipment(
                ns3457Code: codeMatch.code,
                confidence: 0.85,
                boundingBox: boundingBox,
                suggestedName: codeMatch.name,
                category: codeMatch.category
            )
        }
        
        // Check for equipment keywords in Norwegian/English
        let keywords = extractEquipmentKeywords(from: text)
        if let keyword = keywords.first,
           let mapping = NS3457CodeMapping.findCode(for: keyword) {
            return DetectedEquipment(
                ns3457Code: mapping.code,
                confidence: 0.7,
                boundingBox: boundingBox,
                suggestedName: mapping.name,
                category: mapping.category
            )
        }
        
        return nil
    }
    
    /// Parse TFM (Tverrfaglig Merkesystem) codes
    private func parseTFMCode(_ text: String) -> (code: String, name: String, category: EquipmentCategory)? {
        // TFM format: =SYSTEM.NR-COMPONENT_NR (e.g., =360.01-PU001)
        let pattern = #"=?(\d{3})\.?(\d{2})?-?([A-Z]{2})(\d{3})?"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
            return nil
        }
        
        // Extract component code (e.g., "PU")
        if let componentRange = Range(match.range(at: 3), in: text) {
            let componentCode = String(text[componentRange])
            
            // Find the mapping for this component
            for (_, value) in NS3457CodeMapping.mappings {
                if value.code == componentCode {
                    return (componentCode, value.name, value.category)
                }
            }
            
            // Unknown component, return with generic info
            return (componentCode, "Ukjent komponent (\(componentCode))", .other)
        }
        
        return nil
    }
    
    /// Extract equipment-related keywords from text
    private func extractEquipmentKeywords(from text: String) -> [String] {
        let equipmentWords = [
            "pumpe", "pump", "vifte", "fan", "ventil", "valve", "motor",
            "sensor", "måler", "meter", "brannslukker", "radiator",
            "kjøle", "varme", "heater", "cooler", "filter", "kompressor",
            "transformator", "tavle", "panel", "bryter", "switch"
        ]
        
        let lowercaseText = text.lowercased()
        return equipmentWords.filter { lowercaseText.contains($0) }
    }
    
    /// Map Vision classification to equipment
    private func mapClassificationToEquipment(_ observation: VNClassificationObservation) -> DetectedEquipment? {
        let identifier = observation.identifier.lowercased()
        
        // Try to find a matching NS3457 code
        if let mapping = NS3457CodeMapping.findCode(for: identifier) {
            return DetectedEquipment(
                ns3457Code: mapping.code,
                confidence: observation.confidence,
                boundingBox: .zero, // Classification doesn't provide bounding box
                suggestedName: mapping.name,
                category: mapping.category
            )
        }
        
        return nil
    }
    
    // MARK: - Utility Methods
    
    /// Clear all detections
    func clearDetections() {
        detectedEquipment.removeAll()
        errorMessage = nil
    }
}

// MARK: - Detection Errors

enum DetectionError: LocalizedError {
    case invalidImage
    case processingFailed
    case modelNotLoaded
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Ugyldig bilde"
        case .processingFailed:
            return "Kunne ikke behandle bildet"
        case .modelNotLoaded:
            return "AI-modell ikke lastet"
        case .serverError(let message):
            return "Serverfeil: \(message)"
        }
    }
}
