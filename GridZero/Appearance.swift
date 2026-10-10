import SwiftUI

enum Theme: String, Codable, CaseIterable, Identifiable {
    case ink, moss, clay
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    func accent(dark: Bool) -> Color {
        switch self {
        case .ink: Color(hex: dark ? 0x91B7E8 : 0x315E91)
        case .moss: Color(hex: dark ? 0xA8C6A7 : 0x416B50)
        case .clay: Color(hex: dark ? 0xE8B39D : 0xA45C43)
        }
    }
}

enum Appearance: String, Codable, CaseIterable, Identifiable {
    case system, light, dark, scheduled
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    func scheme(at date: Date, lightAt: Int, darkAt: Int) -> ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        case .scheduled:
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            let now = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            let isLight = lightAt < darkAt ? now >= lightAt && now < darkAt : now >= lightAt || now < darkAt
            return isLight ? .light : .dark
        }
    }
}

struct Palette {
    let theme: Theme
    let dark: Bool
    var paper: Color { Color(hex: dark ? 0x151A1B : 0xFAF9F5) }
    var surface: Color { Color(hex: dark ? 0x21282A : 0xF0EFEA) }
    var ink: Color { Color(hex: dark ? 0xF0F0E9 : 0x252C30) }
    var secondary: Color { Color(hex: dark ? 0xA2ADB0 : 0x687476) }
    var line: Color { Color(hex: dark ? 0x495456 : 0xBFC5C2) }
    var strongLine: Color { Color(hex: dark ? 0x99A3A0 : 0x6E7C78) }
    var accent: Color { theme.accent(dark: dark) }
    var error: Color { Color(hex: dark ? 0xFFB4AC : 0xB33735) }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255,
                  green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
    }
}
