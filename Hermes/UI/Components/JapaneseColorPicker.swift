import SwiftUI

struct JapaneseColorPicker: View {
    @Binding var selectedColor: JapaneseColor
    @State private var showingPicker = false
    
    var body: some View {
        Button(action: { showingPicker.toggle() }) {
            HStack(spacing: 6) {
                Circle()
                    .fill(selectedColor.color)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.primary.opacity(0.2), lineWidth: 0.5)
                    )
                
                VStack(alignment: .leading, spacing: 0) {
                    Text(selectedColor.chineseName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary)
                    Text(selectedColor.katakanaName)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingPicker, arrowEdge: .bottom) {
            ColorPickerPopover(selectedColor: $selectedColor, isPresented: $showingPicker)
        }
    }
}

struct ColorPickerPopover: View {
    @Binding var selectedColor: JapaneseColor
    @Binding var isPresented: Bool
    
    let columns = Array(repeating: GridItem(.fixed(50), spacing: 8), count: 6)
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("日本传统色")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
            
            // Color Grid
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(JapaneseColorPalette.colors) { color in
                        ColorCell(
                            color: color,
                            isSelected: color.hex == selectedColor.hex,
                            action: {
                                selectedColor = color
                                JapaneseColorPalette.saveSelectedColor(color)
                                isPresented = false
                            }
                        )
                    }
                }
                .padding(16)
            }
            .frame(width: 380, height: 420)
        }
        .background(.regularMaterial)
    }
}

struct ColorCell: View {
    let color: JapaneseColor
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.color)
                    .frame(width: 50, height: 50)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                isSelected ? Color.blue : Color.primary.opacity(0.1),
                                lineWidth: isSelected ? 2.5 : 0.5
                            )
                    )
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                
                VStack(spacing: 1) {
                    Text(color.chineseName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.primary)
                    Text(color.katakanaName)
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
                .frame(width: 54)
            }
        }
        .buttonStyle(.plain)
    }
}
