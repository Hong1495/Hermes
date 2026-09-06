import SwiftUI

struct LiquidGlassSegmentedControl<T: Hashable & Identifiable>: View {
    let items: [T]
    @Binding var selection: T
    let title: (T) -> String
    var icon: ((T) -> String)? = nil
    var fillsAvailableWidth = false
    @Namespace private var segmentNamespace
    @State private var hoveredItem: T? = nil

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 3) {
                ForEach(items) { item in
                    segment(for: item)
                }
            }
            .padding(3)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(Theme.Colors.glassBorder.opacity(0.42), lineWidth: 0.75)
            }
        }
        .fixedSize(horizontal: !fillsAvailableWidth, vertical: true)
        .frame(maxWidth: fillsAvailableWidth ? .infinity : nil, alignment: .leading)
    }

    private func segment(for item: T) -> some View {
        let isSelected = selection == item
        let isHovered = hoveredItem == item && !isSelected

        return Button {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                selection = item
            }
        } label: {
            HStack(spacing: 6) {
                if let icon = icon?(item) {
                    Image(systemName: icon)
                        .symbolRenderingMode(.hierarchical)
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 15, height: 15)
                }
                Text(title(item))
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .frame(maxWidth: fillsAvailableWidth ? .infinity : nil, minHeight: 28)
            .padding(.horizontal, fillsAvailableWidth ? 8 : 11)
            .contentShape(Capsule())
            .foregroundStyle(
                isSelected || isHovered
                    ? Theme.Colors.textPrimary
                    : Theme.Colors.textSecondary
            )
            .glassEffect(
                isSelected
                    ? .regular.tint(Theme.Colors.accent.opacity(0.14)).interactive()
                    : (isHovered ? .clear.interactive() : .identity),
                in: Capsule()
            )
            .glassEffectID(
                isSelected ? "segment-selection" : (isHovered ? "segment-hover" : nil),
                in: segmentNamespace
            )
            .glassEffectTransition(.matchedGeometry)
        }
        .buttonStyle(.plain)
        .layoutPriority(1)
        .onHover { hovering in
            withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
                if hovering {
                    hoveredItem = item
                } else if hoveredItem == item {
                    hoveredItem = nil
                }
            }
        }
    }
}
