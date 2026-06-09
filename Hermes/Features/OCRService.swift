import Cocoa
import Vision

class OCRService {
    static let shared = OCRService()
    
    private init() {}

    private func completeOnMain(_ completion: @escaping (String?) -> Void, with text: String?) {
        DispatchQueue.main.async {
            completion(text)
        }
    }
    
    func recognizeText(from image: NSImage, completion: @escaping (String?) -> Void) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            completeOnMain(completion, with: nil)
            return
        }
        
        let request = VNRecognizeTextRequest { request, error in
            guard error == nil else {
                print("OCR Error: \(String(describing: error))")
                self.completeOnMain(completion, with: nil)
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                self.completeOnMain(completion, with: nil)
                return
            }
            
            let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
            self.completeOnMain(completion, with: text)
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        
        // Supports Chinese and English
        request.recognitionLanguages = ["zh-Hans", "en-US"]
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                print("Failed to perform OCR: \(error)")
                self.completeOnMain(completion, with: nil)
            }
        }
    }
}
