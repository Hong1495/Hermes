//
//  StudioView.swift
//  Hermes
//
//  Created by Hermes AI Assistant.
//

import SwiftUI
import UniformTypeIdentifiers

struct StudioView: View {
    @Bindable var item: HermesItem
    
    @State private var backgroundColor: Color = .blue.opacity(0.3)
    @State private var shadowRadius: CGFloat = 20
    @State private var padding: CGFloat = 60
    @State private var cornerRadius: CGFloat = 12
    
    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                Color(NSColor.windowBackgroundColor)
                    .ignoresSafeArea()
                
                artworkView
                    .drawingGroup()
                    .padding(40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Divider()
            
            Form {
                Section("Background") {
                    ColorPicker("Fill Color", selection: $backgroundColor)
                }
                
                Section("Appearance") {
                    Slider(value: $padding, in: 0...100) {
                        Text("Padding")
                    }
                    Slider(value: $shadowRadius, in: 0...50) {
                        Text("Shadow")
                    }
                    Slider(value: $cornerRadius, in: 0...40) {
                        Text("Radius")
                    }
                }
                
                Section("Actions") {
                    Button("Copy to Clipboard") {
                        copyToClipboard()
                    }
                }
            }
            .formStyle(.grouped)
            .frame(width: 250)
        }
        .toolbar {
            ToolbarItem {
                Button(action: importNewImage) {
                    Label("Replace Image", systemImage: "photo.badge.plus")
                }
            }
        }
    }
    
    @ViewBuilder
    var artworkView: some View {
        ZStack {
            backgroundColor
            
            if let imageName = item.coverImageName,
               let imageData = StorageService.shared.loadImageData(filename: imageName),
               let nsImage = NSImage(data: imageData) {
                
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .shadow(color: .black.opacity(0.4), radius: shadowRadius, x: 0, y: shadowRadius/2)
                    .padding(padding)
            } else {
                ContentUnavailableView("No Image", systemImage: "photo")
                    .padding(padding)
            }
        }
        .aspectRatio(16/9, contentMode: .fit)
        .background(.white)
    }
    
    private func importNewImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    let data = try Data(contentsOf: url)
                    let filename = try StorageService.shared.saveImage(data: data, originalFilename: url.lastPathComponent)
                    
                    item.coverImageName = filename
                    if item.title.isEmpty {
                        item.title = url.deletingPathExtension().lastPathComponent
                    }
                } catch {
                    print("Failed to import image: \(error)")
                }
            }
        }
    }
    
    @MainActor
    private func copyToClipboard() {
        let renderer = ImageRenderer(content: artworkView.frame(width: 1920, height: 1080))
        if let nsImage = renderer.nsImage {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects([nsImage])
        }
    }
}
