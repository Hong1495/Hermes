import Cocoa
import Vision

class OCRService {
    static let shared = OCRService()

    private init() {}

    /// 可选语言：与设置页 OCR 语言多选保持一致
    static let supportedLanguages: [(code: String, label: String)] = [
        ("zh-Hans", "简体中文"),
        ("zh-Hant", "繁體中文"),
        ("en-US", "英语"),
        ("ja-JP", "日语"),
        ("ko-KR", "韩语"),
        ("fr-FR", "法语"),
        ("es-ES", "西班牙语"),
        ("de-DE", "德语")
    ]

    /// 读取用户在设置中选择的 OCR 语言，逗号分隔；为空则用默认中英文
    private var configuredLanguages: [String] {
        let stored = UserDefaults.standard.string(forKey: "ocrLanguages") ?? "zh-Hans,en-US"
        let codes = stored
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return codes.isEmpty ? ["zh-Hans", "en-US"] : codes
    }

    private func effectiveLanguages() -> [String] {
        let configured = configuredLanguages

        let supported: Set<String>
        do {
            supported = Set(try VNRecognizeTextRequest.supportedRecognitionLanguages(
                for: .accurate,
                revision: VNRecognizeTextRequestRevision3
            ))
        } catch {
            return configured
        }

        let filtered = configured.filter { supported.contains($0) }
        return filtered.isEmpty ? ["zh-Hans", "en-US"] : filtered
    }

    private func completeOnMain(_ completion: @escaping (OCRResult?) -> Void, with result: OCRResult?) {
        DispatchQueue.main.async {
            completion(result)
        }
    }

    func recognizeText(from image: NSImage, completion: @escaping (OCRResult?) -> Void) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            completeOnMain(completion, with: nil)
            return
        }

        let request = VNRecognizeTextRequest { request, error in
            guard error == nil else {
                self.completeOnMain(completion, with: nil)
                return
            }

            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                self.completeOnMain(completion, with: nil)
                return
            }

            let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
            self.completeOnMain(completion, with: OCRResult(text: text))
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = effectiveLanguages()

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                self.completeOnMain(completion, with: nil)
            }
        }
    }
}

/// OCR 识别结果
struct OCRResult {
    let text: String
}
