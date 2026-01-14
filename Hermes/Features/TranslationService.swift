import Foundation

class TranslationService {
    static let shared = TranslationService()
    
    private init() {}
    
    func translate(text: String, source: String = "auto", target: String = "zh-CN", completion: @escaping (String) -> Void) {
        // Use Google Translate free endpoint (Note: This is unofficial and may rate limit, but enables "Real" translation functionality for the user)
        // URL: https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=zh-CN&dt=t&q=TEXT
        
        var urlComponents = URLComponents(string: "https://translate.googleapis.com/translate_a/single")
        urlComponents?.queryItems = [
            URLQueryItem(name: "client", value: "gtx"),
            URLQueryItem(name: "sl", value: source),
            URLQueryItem(name: "tl", value: target),
            URLQueryItem(name: "dt", value: "t"),
            URLQueryItem(name: "q", value: text)
        ]
        
        guard let url = urlComponents?.url else {
            completion("Error: Invalid URL")
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion("Error: \(error.localizedDescription)") }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async { completion("Error: No data") }
                return
            }
            
            // Response is a weird nested JSON array: [[["TranslatedText", "SourceText", ...]], ...]
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [Any],
                   let sentences = json[0] as? [[Any]] {
                    
                    var fullText = ""
                    for sentence in sentences {
                        if let line = sentence[0] as? String {
                            fullText += line
                        }
                    }
                    
                    DispatchQueue.main.async {
                        completion(fullText)
                    }
                } else {
                    DispatchQueue.main.async { completion("Error: Could not parse response") }
                }
            } catch {
                DispatchQueue.main.async { completion("Error: \(error.localizedDescription)") }
            }
        }
        task.resume()
    }
}
