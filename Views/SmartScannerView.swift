import AVFoundation
import SwiftUI

/// Advanced camera view with live object detection overlay
struct SmartScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var detectionService = ObjectDetectionService()

    @Binding var detectedEquipment: [DetectedEquipment]
    var onCodeScanned: ((String) -> Void)? = nil

    @State private var showingAnalysis = false
    @State private var capturedImage: UIImage?
    @State private var isAnalyzing = false
    @State private var scanMode: ScanMode = .smart

    @State private var scannedBarcode: String = ""
    @State private var manualCode: String = ""

    enum ScanMode: String, CaseIterable {
        case smart = "Smart"
        case code = "Kode"
        case manual = "Manuell"

        var icon: String {
            switch self {
            case .smart: return "sparkles"
            case .code: return "qrcode.viewfinder"
            case .manual: return "hand.tap"
            }
        }
    }

    var body: some View {
        ZStack {
            // Background Layer based on mode
            if scanMode == .code {
                ScannerView(scannedText: $scannedBarcode)
                    .ignoresSafeArea()
            } else if scanMode == .manual {
                Color.black.opacity(0.85)  // Dark background for manual entry
                    .ignoresSafeArea()
            } else {
                // Smart scan preview
                CameraPreviewView(cameraManager: cameraManager)
                    .ignoresSafeArea()

                // Detection Overlays
                if !detectionService.detectedEquipment.isEmpty {
                    DetectionOverlayView(detections: detectionService.detectedEquipment)
                }
            }

            // UI Controls
            VStack {
                // Top Bar
                topBar

                Spacer()

                if scanMode == .smart {
                    // Detection Results (if any)
                    if !detectionService.detectedEquipment.isEmpty {
                        detectionResultsCard
                    }

                    // Bottom Controls
                    bottomControls
                } else if scanMode == .manual {
                    manualEntryView
                    Spacer()
                }
            }

            // Loading Overlay
            if isAnalyzing {
                analysisOverlay
            }
        }
        .onAppear {
            if scanMode == .smart { cameraManager.startSession() }
        }
        .onDisappear {
            cameraManager.stopSession()
        }
        .onChange(of: scanMode) { _, newMode in
            if newMode == .smart {
                cameraManager.startSession()
            } else {
                cameraManager.stopSession()
            }
        }
        .onChange(of: scannedBarcode) { _, newValue in
            if !newValue.isEmpty {
                onCodeScanned?(newValue)
                dismiss()  // Close the scanner sheet once scanned
            }
        }
        .onChange(of: cameraManager.currentFrame) { _, frame in
            if scanMode == .smart, let frame = frame {
                detectionService.processFrame(frame)
            }
        }
        .sheet(isPresented: $showingAnalysis) {
            if let equipment = detectionService.detectedEquipment.first {
                EquipmentDetailView(equipment: equipment)
            }
        }
    }

    // MARK: - View Components

    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }

            Spacer()

            // Scan Mode Picker
            Picker("Modus", selection: $scanMode) {
                ForEach(ScanMode.allCases, id: \.self) { mode in
                    Label(mode.rawValue, systemImage: mode.icon)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 250)
            .background(Color.black.opacity(0.5))
            .cornerRadius(8)

            Spacer()

            // Flash Toggle
            Button(action: { cameraManager.toggleFlash() }) {
                Image(systemName: cameraManager.isFlashOn ? "bolt.fill" : "bolt.slash")
                    .font(.title2)
                    .foregroundColor(cameraManager.isFlashOn ? .yellow : .white)
                    .padding(12)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
        }
        .padding()
    }

    private var detectionResultsCard: some View {
        VStack(spacing: 12) {
            ForEach(detectionService.detectedEquipment.prefix(3)) { equipment in
                HStack {
                    Image(systemName: equipment.category.icon)
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(categoryColor(for: equipment.category))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(equipment.suggestedName)
                            .font(.headline)
                            .foregroundColor(.white)

                        HStack {
                            Text(equipment.ns3457Code)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.blue)
                                .cornerRadius(4)

                            Text("\(Int(equipment.confidence * 100))% sikker")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }

                    Spacer()

                    Button(action: {
                        detectedEquipment = [equipment]
                        showingAnalysis = true
                    }) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.white)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.7))
                .cornerRadius(12)
            }
        }
        .padding(.horizontal)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(), value: detectionService.detectedEquipment.count)
    }

    private var bottomControls: some View {
        HStack(spacing: 40) {
            // Gallery Button
            Button(action: selectFromGallery) {
                VStack {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title2)
                    Text("Galleri")
                        .font(.caption)
                }
                .foregroundColor(.white)
            }

            // Capture Button
            Button(action: captureAndAnalyze) {
                ZStack {
                    Circle()
                        .strokeBorder(.white, lineWidth: 4)
                        .frame(width: 80, height: 80)

                    Circle()
                        .fill(isAnalyzing ? Color.gray : Color.white)
                        .frame(width: 65, height: 65)

                    if isAnalyzing {
                        ProgressView()
                            .tint(.black)
                    }
                }
            }
            .disabled(isAnalyzing)

            // Manual Code Entry
            Button(action: { scanMode = .manual }) {
                VStack {
                    Image(systemName: "keyboard")
                        .font(.title2)
                    Text("Tast inn")
                        .font(.caption)
                }
                .foregroundColor(.white)
            }
        }
        .padding(.vertical, 30)
        .padding(.horizontal)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var analysisOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                Text("Analyserer bilde...")
                    .font(.headline)
                    .foregroundColor(.white)

                Text("Bruker AI for å identifisere utstyr")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(40)
            .background(Color.black.opacity(0.8))
            .cornerRadius(20)
        }
    }

    private var manualEntryView: some View {
        VStack(spacing: 24) {
            Text("Skriv inn utstyrskode")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            TextField("NS3457-kode (f.eks. PU)", text: $manualCode)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.characters)
                .font(.title3)
                .padding(.horizontal, 40)

            Button(action: {
                if !manualCode.isEmpty {
                    onCodeScanned?(manualCode)
                    dismiss()
                }
            }) {
                Text("Gå til sjekkliste")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(manualCode.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .padding(.horizontal, 40)
            }
            .disabled(manualCode.isEmpty)
        }
    }
    private var analysisOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                Text("Analyserer bilde...")
                    .font(.headline)
                    .foregroundColor(.white)

                Text("Bruker AI for å identifisere utstyr")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(40)
            .background(Color.black.opacity(0.8))
            .cornerRadius(20)
        }
    }

    // MARK: - Actions

    private func captureAndAnalyze() {
        guard let image = cameraManager.capturePhoto() else { return }

        isAnalyzing = true
        capturedImage = image

        Task {
            do {
                // First try local detection
                let localResults = try await detectionService.processImage(image)

                // Then enhance with server-side AI if needed
                if localResults.isEmpty {
                    let serverResponse = try await detectionService.analyzeWithAI(image)

                    // Convert server response to local model
                    let serverEquipment = serverResponse.detectedObjects.map { dto in
                        DetectedEquipment(
                            ns3457Code: dto.ns3457Code,
                            confidence: dto.confidence,
                            boundingBox: dto.boundingBox.map {
                                CGRect(
                                    x: CGFloat($0.x), y: CGFloat($0.y),
                                    width: CGFloat($0.width), height: CGFloat($0.height))
                            } ?? .zero,
                            suggestedName: dto.suggestedName,
                            category: EquipmentCategory(rawValue: dto.category) ?? .other
                        )
                    }

                    await MainActor.run {
                        detectedEquipment = serverEquipment
                    }
                } else {
                    await MainActor.run {
                        detectedEquipment = localResults
                    }
                }

                if !detectedEquipment.isEmpty {
                    showingAnalysis = true
                }

            } catch {
                print("Analysis error: \(error)")
            }

            isAnalyzing = false
        }
    }

    private func selectFromGallery() {
        // Would present image picker
        // For now, just a placeholder
    }

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
}

// MARK: - Detection Overlay View

struct DetectionOverlayView: View {
    let detections: [DetectedEquipment]

    var body: some View {
        GeometryReader { geometry in
            ForEach(detections) { detection in
                if detection.boundingBox != .zero {
                    let rect = convertBoundingBox(detection.boundingBox, in: geometry.size)

                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(categoryColor(for: detection.category), lineWidth: 3)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .overlay(alignment: .topLeading) {
                            Text(detection.ns3457Code)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(categoryColor(for: detection.category))
                                .cornerRadius(4)
                                .offset(x: rect.minX, y: rect.minY - 20)
                        }
                }
            }
        }
    }

    private func convertBoundingBox(_ box: CGRect, in size: CGSize) -> CGRect {
        // Vision returns normalized coordinates with origin at bottom-left
        // Convert to SwiftUI coordinates
        CGRect(
            x: box.minX * size.width,
            y: (1 - box.maxY) * size.height,
            width: box.width * size.width,
            height: box.height * size.height
        )
    }

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
}

// MARK: - Camera Preview

struct CameraPreviewView: UIViewRepresentable {
    @ObservedObject var cameraManager: CameraManager

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)

        if let previewLayer = cameraManager.previewLayer {
            previewLayer.frame = view.bounds
            previewLayer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(previewLayer)
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            cameraManager.previewLayer?.frame = uiView.bounds
        }
    }
}

// MARK: - Camera Manager

class CameraManager: NSObject, ObservableObject {
    @Published var currentFrame: CVPixelBuffer?
    @Published var isFlashOn = false

    private let captureSession = AVCaptureSession()
    private var videoOutput = AVCaptureVideoDataOutput()
    private var photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "no.zenti.camera.session")

    var previewLayer: AVCaptureVideoPreviewLayer?

    override init() {
        super.init()
        setupCamera()
    }

    private func setupCamera() {
        captureSession.sessionPreset = .high

        guard
            let camera = AVCaptureDevice.default(
                .builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: camera)
        else {
            return
        }

        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }

        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]

        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }

        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
    }

    func startSession() {
        sessionQueue.async { [weak self] in
            self?.captureSession.startRunning()
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            self?.captureSession.stopRunning()
        }
    }

    func toggleFlash() {
        guard
            let device = AVCaptureDevice.default(
                .builtInWideAngleCamera, for: .video, position: .back),
            device.hasTorch
        else { return }

        do {
            try device.lockForConfiguration()
            device.torchMode = isFlashOn ? .off : .on
            isFlashOn.toggle()
            device.unlockForConfiguration()
        } catch {
            print("Flash toggle error: \(error)")
        }
    }

    func capturePhoto() -> UIImage? {
        guard let connection = photoOutput.connection(with: .video) else { return nil }

        // For simplicity, return a snapshot from the current frame
        // In production, use photoOutput.capturePhoto() with delegate
        guard let pixelBuffer = currentFrame else { return nil }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }

        return UIImage(cgImage: cgImage)
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        DispatchQueue.main.async { [weak self] in
            self?.currentFrame = pixelBuffer
        }
    }
}

#Preview {
    SmartScannerView(detectedEquipment: .constant([]))
}
