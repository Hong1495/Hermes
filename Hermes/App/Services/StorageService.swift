//
//  StorageService.swift
//  Hermes
//
//  Created by Hermes AI Assistant.
//

import Foundation
import AppKit

class StorageService {
    static let shared = StorageService()
    
    private let fileManager = FileManager.default
    
    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    private var imagesDirectory: URL {
        let url = documentsDirectory.appendingPathComponent("Images", isDirectory: true)
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }
    
    func saveImage(data: Data, originalFilename: String? = nil) throws -> String {
        let fileExtension = originalFilename?.components(separatedBy: ".").last ?? "jpg"
        let uniqueID = UUID().uuidString
        let filename = "\(uniqueID).\(fileExtension)"
        let destinationURL = imagesDirectory.appendingPathComponent(filename)
        try data.write(to: destinationURL)
        return filename
    }
    
    func loadImageData(filename: String) -> Data? {
        let fileURL = imagesDirectory.appendingPathComponent(filename)
        return try? Data(contentsOf: fileURL)
    }
}
