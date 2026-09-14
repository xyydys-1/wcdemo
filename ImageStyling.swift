import SwiftUI
import UIKit

// The photograph stays sharp. A narrow, clear system-glass backing supplies the
// same optical edge family as the chat bubbles; no gradient is painted over it.
private struct PhotoSurface: ViewModifier {
    let corner: CGFloat
    @Environment(\.displayScale) private var displayScale

    func body(content: Content) -> some View {
        let edge = max(0.5, 1 / displayScale)
        content
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous),
                       style: FillStyle(antialiased: true))
            .background {
                Color.clear
                    .glassEffect(.clear, in: RoundedRectangle(cornerRadius: corner + edge, style: .continuous))
                    .padding(-edge)
                    .allowsHitTesting(false)
            }
    }
}

extension View {
    func photoSurface(cornerRadius: CGFloat) -> some View {
        modifier(PhotoSurface(corner: cornerRadius))
    }
}

enum DemoArtwork {
    // Existing bundled picture assets, never overwrite a user-selected avatar.
    static func profile(_ id: String) -> String {
        let known = ["me": "photo_chibi", "xixi": "photo_avatar", "shore": "photo_chibi",
                     "qiushui": "photo_13", "changli": "photo_14", "jiazhu": "photo_7",
                     "cartethyia": "photo_15", "shorekeeper": "photo_13", "xiaoka": "photo_14"]
        if let key = known[id] { return key }
        let pictures = ["photo_7", "photo_13", "photo_14", "photo_15", "photo_chibi", "photo_avatar"]
        let index = id.utf8.reduce(0) { ($0 + Int($1)) % pictures.count }
        return pictures[index]
    }
}

struct ArtworkLabel: View {
    let title: String
    let artwork: String
    var titleColor: Color = .primary
    var body: some View {
        HStack(spacing: 12) {
            RowArtwork(name: artwork)
            Text(title).foregroundStyle(titleColor)
        }
        .alignmentGuide(.listRowSeparatorLeading) { _ in 44 }
    }
}

struct RowArtwork: View {
    let name: String
    var size: CGFloat = 32
    var body: some View {
        StoredPhoto(source: "row_" + name, maxPixel: 128)
            .frame(width: size, height: size)
            .photoSurface(cornerRadius: size * 0.24)
            .accessibilityHidden(true)
    }
}
