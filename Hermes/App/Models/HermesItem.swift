//
//  HermesItem.swift
//  Hermes
//
//  Created by Hermes AI Assistant.
//

import Foundation
import SwiftData

enum ItemScene: String, Codable, CaseIterable, Identifiable {
    case article
    case draft
    case image
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .article: return "doc.text.viewfinder"
        case .draft: return "square.and.pencil"
        case .image: return "photo.on.rectangle"
        }
    }
}

enum ItemStatus: String, Codable {
    case inbox
    case archived
    case trash
}

@Model
final class HermesItem {
    var id: UUID
    var title: String
    var content: String
    var timestamp: Date
    var sceneRawValue: String
    var statusRawValue: String
    var sourceURL: String?
    var summary: String?
    var coverImageName: String?
    
    init(title: String, content: String = "", scene: ItemScene = .article, status: ItemStatus = .inbox) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.timestamp = Date()
        self.sceneRawValue = scene.rawValue
        self.statusRawValue = status.rawValue
    }
    
    var scene: ItemScene {
        get { ItemScene(rawValue: sceneRawValue) ?? .article }
        set { sceneRawValue = newValue.rawValue }
    }
    
    var status: ItemStatus {
        get { ItemStatus(rawValue: statusRawValue) ?? .inbox }
        set { statusRawValue = newValue.rawValue }
    }
}
