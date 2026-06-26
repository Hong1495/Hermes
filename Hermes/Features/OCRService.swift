import Cocoa
import Vision
import OSLog

class OCRService {
    static let shared = OCRService()
    private let logger = Logger(subsystem: "hera.Hermes", category: "OCR")
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

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
        let stored = UserDefaults.standard.string(forKey: AppSettings.Key.ocrLanguages) ?? AppSettings.Default.ocrLanguages
        let codes = stored
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return codes.isEmpty ? ["zh-Hans", "en-US"] : codes
    }

    private func effectiveLanguages(for request: VNRecognizeTextRequest = VNRecognizeTextRequest()) -> [String] {
        let configured = configuredLanguages

        let supported: Set<String>
        do {
            supported = Set(try request.supportedRecognitionLanguages())
        } catch {
            logger.warning("读取 OCR 支持语言失败: \(error.localizedDescription, privacy: .public)")
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
            logger.error("OCR 输入图片无法转换为 CGImage")
            completeOnMain(completion, with: nil)
            return
        }

        let variants = recognitionVariants(from: cgImage)
        DispatchQueue.global(qos: .userInitiated).async {
            for variant in variants {
                switch self.recognizeTextSynchronously(from: variant.image) {
                case .success(let text):
                    if !text.isEmpty {
                        self.logger.debug("OCR 命中策略: \(variant.name, privacy: .public)")
                        self.completeOnMain(completion, with: OCRResult(text: text))
                        return
                    }
                case .failure(let error):
                    self.logger.warning("OCR 策略失败 [\(variant.name, privacy: .public)]: \(error.localizedDescription, privacy: .public)")
                }
            }

            self.completeOnMain(completion, with: OCRResult(text: ""))
        }
    }

    private struct ImageVariant {
        let name: String
        let image: CGImage
    }

    private func recognitionVariants(from image: CGImage) -> [ImageVariant] {
        var variants = [ImageVariant(name: "original", image: image)]

        let width = image.width
        let height = image.height
        let longestSide = max(width, height)
        let shortestSide = min(width, height)

        if shortestSide < 900 || longestSide < 1600 {
            let desiredScale: CGFloat = shortestSide < 450 ? 3 : 2
            let maxScale = CGFloat(4096) / CGFloat(longestSide)
            let scale = min(desiredScale, maxScale)
            guard scale > 1.15 else {
                if let enhanced = enhancedImage(from: image) {
                    variants.append(ImageVariant(name: "enhanced", image: enhanced))
                }
                return variants
            }
            if let scaled = scaledImage(image, by: scale) {
                variants.append(ImageVariant(name: String(format: "scaled-%.1fx", scale), image: scaled))
                if let enhancedScaled = enhancedImage(from: scaled) {
                    variants.append(ImageVariant(name: String(format: "scaled-%.1fx-enhanced", scale), image: enhancedScaled))
                }
            }
        }

        if let enhanced = enhancedImage(from: image) {
            variants.append(ImageVariant(name: "enhanced", image: enhanced))
        }

        return variants
    }

    private func recognizeTextSynchronously(from image: CGImage) -> Result<String, Error> {
        var recognitionError: Error?
        var recognizedText = ""

        let request = VNRecognizeTextRequest { request, error in
            if let error {
                recognitionError = error
                return
            }

            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                recognizedText = ""
                return
            }

            recognizedText = observations
                .sorted { lhs, rhs in
                    let yDelta = abs(lhs.boundingBox.minY - rhs.boundingBox.minY)
                    if yDelta > 0.02 {
                        return lhs.boundingBox.minY > rhs.boundingBox.minY
                    }
                    return lhs.boundingBox.minX < rhs.boundingBox.minX
                }
                .compactMap { $0.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
        }

        if let bestRevision = VNRecognizeTextRequest.supportedRevisions.max() {
            request.revision = bestRevision
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = effectiveLanguages(for: request)

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return .failure(error)
        }

        if let recognitionError {
            return .failure(recognitionError)
        }

        return .success(recognizedText)
    }

    private func scaledImage(_ image: CGImage, by scale: CGFloat) -> CGImage? {
        let width = Int(CGFloat(image.width) * scale)
        let height = Int(CGFloat(image.height) * scale)
        guard width > 0, height > 0 else { return nil }

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    private func enhancedImage(from image: CGImage) -> CGImage? {
        let input = CIImage(cgImage: image)
        guard let colorControls = CIFilter(name: "CIColorControls") else { return nil }
        colorControls.setValue(input, forKey: kCIInputImageKey)
        colorControls.setValue(0, forKey: kCIInputSaturationKey)
        colorControls.setValue(1.35, forKey: kCIInputContrastKey)
        colorControls.setValue(0.03, forKey: kCIInputBrightnessKey)

        guard let sharpen = CIFilter(name: "CISharpenLuminance") else { return nil }
        sharpen.setValue(colorControls.outputImage, forKey: kCIInputImageKey)
        sharpen.setValue(0.4, forKey: kCIInputSharpnessKey)

        guard let output = sharpen.outputImage else { return nil }
        return ciContext.createCGImage(output, from: input.extent)
    }
}

/// OCR 识别结果
struct OCRResult {
    let text: String
}
