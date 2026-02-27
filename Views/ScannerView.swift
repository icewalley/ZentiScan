
import SwiftUI
import VisionKit

struct ScannerView: UIViewControllerRepresentable {
    @Binding var scannedText: String
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> DataScannerViewController {
        // We look for text and barcodes
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text(), .barcode()],
            qualityLevel: .balanced,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }
    
    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let parent: ScannerView
        
        init(_ parent: ScannerView) {
            self.parent = parent
        }
        
        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            switch item {
            case .text(let text):
                parent.scannedText = text.transcript
                parent.presentationMode.wrappedValue.dismiss()
            case .barcode(let code):
                parent.scannedText = code.payloadStringValue ?? ""
                parent.presentationMode.wrappedValue.dismiss()
            default:
                break
            }
        }
    }
}
