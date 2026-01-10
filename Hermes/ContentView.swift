//
//  ContentView.swift
//  Hermes
//
//  Created by Hermes AI Assistant.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [HermesItem]
    
    @State private var selectedCategory: String? = "inbox"
    @State private var selectedItemId: UUID?
    
    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selectedCategory)
        } content: {
            ItemListView(category: selectedCategory, selection: $selectedItemId)
        } detail: {
            if let itemId = selectedItemId {
                ItemDetailContainer(itemId: itemId)
            } else {
                ContentUnavailableView("Select an Item", systemImage: "arrow.left.circle")
            }
        }
        #if os(macOS)
        .navigationSplitViewStyle(.balanced)
        #endif
    }
}

// MARK: - Subcomponents

struct SidebarView: View {
    @Binding var selection: String?
    @State private var showURLInput = false
    @State private var urlString = ""
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        List(selection: $selection) {
            Section("Inbox") {
                NavigationLink(value: "inbox") {
                    Label("Unsorted", systemImage: "tray")
                }
            }
            
            Section("Library") {
                NavigationLink(value: ItemScene.article.rawValue) {
                    Label("Read Later", systemImage: ItemScene.article.iconName)
                }
                NavigationLink(value: ItemScene.draft.rawValue) {
                    Label("Writer", systemImage: ItemScene.draft.iconName)
                }
                NavigationLink(value: ItemScene.image.rawValue) {
                    Label("Gallery", systemImage: ItemScene.image.iconName)
                }
            }
            
            Section("System") {
                NavigationLink(value: "trash") {
                    Label("Trash", systemImage: "trash")
                }
            }
        }
        .listStyle(.sidebar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        createNew(type: .draft)
                    } label: {
                        Label("New Draft", systemImage: "square.and.pencil")
                    }
                    
                    Button {
                        presentURLInput()
                    } label: {
                        Label("Add from URL...", systemImage: "link")
                    }
                    
                    Button {
                        importImage()
                    } label: {
                        Label("Import Image...", systemImage: "photo")
                    }
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .alert("Add Link", isPresented: $showURLInput) {
            TextField("https://...", text: $urlString)
            Button("Add") {
                createNew(type: .article, content: urlString)
            }
            Button("Cancel", role: .cancel) { }
        }
    }
    
    private func createNew(type: ItemScene, content: String = "") {
        if type == .article {
             ItemCreationService.createItem(from: content, modelContext: modelContext)
        } else if type == .draft {
             let item = HermesItem(title: "New Draft", scene: .draft, status: .inbox)
             modelContext.insert(item)
        }
    }
    
    private func presentURLInput() {
        urlString = ""
        showURLInput = true
    }
    
    private func importImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    let data = try Data(contentsOf: url)
                    let filename = try StorageService.shared.saveImage(data: data, originalFilename: url.lastPathComponent)
                    let item = HermesItem(title: url.deletingPathExtension().lastPathComponent, scene: .image, status: .inbox)
                    item.coverImageName = filename
                    modelContext.insert(item)
                } catch {
                    print("Error importing: \(error)")
                }
            }
        }
    }
}

struct ItemListView: View {
    var category: String?
    @Binding var selection: UUID?
    @Query private var items: [HermesItem]
    
    init(category: String?, selection: Binding<UUID?>) {
        self.category = category
        self._selection = selection
        
        if let cat = category, ["article", "draft", "image"].contains(cat) {
             _items = Query(filter: #Predicate<HermesItem> { item in
                 item.sceneRawValue == cat && item.statusRawValue != "trash"
             }, sort: \.timestamp, order: .reverse)
        } else if category == "trash" {
             _items = Query(filter: #Predicate<HermesItem> { item in
                 item.statusRawValue == "trash"
             }, sort: \.timestamp, order: .reverse)
        } else {
             _items = Query(filter: #Predicate<HermesItem> { item in
                 item.statusRawValue == "inbox"
             }, sort: \.timestamp, order: .reverse)
        }
    }
    
    var body: some View {
        List(items, selection: $selection) { item in
            HStack {
                Image(systemName: item.scene.iconName)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading) {
                    Text(item.title)
                        .font(.headline)
                    if let summary = item.summary {
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Text(item.timestamp, format: .dateTime)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .tag(item.id)
            .contextMenu {
                Button("Delete", role: .destructive) {
                    item.status = .trash
                }
            }
        }
        .navigationTitle(category?.capitalized ?? "Inbox")
    }
}

struct ItemDetailContainer: View {
    var itemId: UUID
    @Query private var items: [HermesItem]
    
    init(itemId: UUID) {
        self.itemId = itemId
        _items = Query(filter: #Predicate<HermesItem> { $0.id == itemId })
    }
    
    var body: some View {
        if let item = items.first {
            VStack {
                switch item.scene {
                case .article:
                    ReaderView(item: item)
                case .draft:
                    WriterView(item: item)
                case .image:
                    StudioView(item: item)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
