import SwiftUI

// Hyperpop. Dark base, colors that hurt a little.
enum Theme {
    static let bg      = Color(hex: 0x0A0714)
    static let card    = Color(hex: 0x16112B)
    static let edge    = Color(hex: 0x2A2145)
    static let text    = Color(hex: 0xFFFFFF)
    static let dim     = Color(hex: 0xA79DC9)

    static let pink    = Color(hex: 0xFF4FD8)
    static let lime    = Color(hex: 0xCCFF00)
    static let cyan    = Color(hex: 0x00F0FF)
    static let violet  = Color(hex: 0x7B2FFF)
    static let yellow  = Color(hex: 0xFFE600)
    static let orange  = Color(hex: 0xFF7A00)

    static let blobs: [Color] = [pink, violet, cyan, lime, orange]

    static func party(_ p: Party) -> Color {
        switch p {
        case .democrat: cyan
        case .republican: orange
        case .green: lime
        case .independent: yellow
        case .oneHome: pink
        case .nonpartisan: dim
        }
    }

    static func group(_ g: ContestGroup) -> Color {
        switch g {
        case .federal: cyan
        case .districtWide: pink
        case .ward: lime
        case .education: yellow
        case .neighborhood: orange
        case .ballotMeasures: violet
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

enum Haptic {
    static func tap() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }
    static func tick() {
        #if os(iOS)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }
}
