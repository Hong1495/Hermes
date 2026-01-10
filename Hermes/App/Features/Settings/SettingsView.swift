//
//  SettingsView.swift
//  Hermes
//
//  Created by Hermes AI Assistant.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject private var config = AIConfig.shared
    
    var body: some View {
        Form {
            Section("AI Provider (Gemini)") {
                TextField("API Key", text: $config.apiKey)
                    .textFieldStyle(.roundedBorder)
                    .help("Enter your Google Gemini API Key here")
                
                Text("Get your free key at Google AI Studio")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .onTapGesture {
                        if let url = URL(string: "https://aistudio.google.com/app/apikey") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                
                LabeledContent("Model", value: config.modelName)
            }
            
            Section("About") {
                Text("Hermes v0.1.0")
                Text("Powered by Google Gemini 1.5 Flash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(width: 400, height: 250)
    }
}
