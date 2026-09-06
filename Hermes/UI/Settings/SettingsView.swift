import SwiftUI

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general
    
    enum SettingsTab: String, CaseIterable {
        case general = "通用"
        case shortcuts = "快捷键"
        case about = "关于"
        
        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .shortcuts: return "command"
            case .about: return "info.circle"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Toolbar Tab Switcher
            HStack(spacing: 20) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Button(action: {
                        selectedTab = tab
                    }) {
                        VStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 20))
                                .padding(6)
                                .background(selectedTab == tab ? Theme.Colors.accentSoft.opacity(0.5) : Color.clear)
                                .cornerRadius(8)
                                .shadow(color: selectedTab == tab ? .black.opacity(0.05) : .clear, radius: 2, x: 0, y: 1)
                            
                            Text(tab.rawValue)
                                .font(.caption)
                                .fontWeight(selectedTab == tab ? .medium : .regular)
                        }
                        .frame(width: 60)
                        .foregroundColor(selectedTab == tab ? Theme.Colors.accent : Theme.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 28)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity)
            .background(Theme.Colors.panelBackground.opacity(0.5))
            
            Divider()
            
            // Content
            Group {
                switch selectedTab {
                case .general:
                    GeneralSettingsView()
                case .shortcuts:
                    ShortcutsSettingsView()
                case .about:
                    AboutSettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.Colors.background)
        .background(VisualEffectBlur(material: .sidebar, blendingMode: .behindWindow))
        .hideScrollIndicators()
    }
}
