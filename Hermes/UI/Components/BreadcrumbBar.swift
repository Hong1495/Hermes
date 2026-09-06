import SwiftUI

struct BreadcrumbBar: View {
    let breadcrumbs: [URL]
    let onSelect: (URL) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(breadcrumbs.enumerated()), id: \.offset) { index, url in
                    let isLast = index == breadcrumbs.count - 1
                    let isHome = index == 0

                    Button {
                        if !isLast {
                            onSelect(url)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            if isHome {
                                Image(systemName: "house.fill")
                                    .font(.caption)
                            }
                            Text(isHome ? "主目录" : url.lastPathComponent)
                                .font(.subheadline.weight(isLast ? .semibold : .regular))
                                .foregroundStyle(isLast ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(isLast ? Theme.Colors.panelElevated : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isLast)

                    if !isLast {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }
}
