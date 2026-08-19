//
//  Theme.swift
//  daily_log
//
//  The small design system the main window is built from: project colours,
//  card and row chrome, and the two bar shapes used to visualise a rollup.
//

import AppKit
import SwiftUI

// MARK: - Project colours

enum Palette {
    /// Muted, roughly equal-weight hues. Enough separation for a legend of ~6.
    static let swatches: [Color] = [
        Color(red: 0.29, green: 0.51, blue: 0.93),
        Color(red: 0.94, green: 0.53, blue: 0.24),
        Color(red: 0.31, green: 0.70, blue: 0.48),
        Color(red: 0.79, green: 0.36, blue: 0.62),
        Color(red: 0.40, green: 0.45, blue: 0.86),
        Color(red: 0.87, green: 0.42, blue: 0.40),
        Color(red: 0.25, green: 0.64, blue: 0.71),
        Color(red: 0.73, green: 0.61, blue: 0.23),
    ]

    /// Stable for the life of a key — a project keeps its colour across launches.
    static func derivedIndex(for key: String) -> Int {
        var hash: UInt64 = 5381
        for byte in key.utf8 { hash = (hash &* 33) &+ UInt64(byte) }
        return Int(hash % UInt64(swatches.count))
    }

    /// Wraps rather than traps. A chosen index is written to disk and outlives
    /// the palette that produced it, so shortening `swatches` must degrade to a
    /// different colour, never a crash on someone's existing projects.
    static func color(at index: Int) -> Color {
        let count = swatches.count
        return swatches[((index % count) + count) % count]
    }

    /// The colour a key falls back to when nothing has been chosen.
    static func color(for key: String) -> Color {
        guard !key.isEmpty else { return Color(nsColor: .systemGray) }
        return color(at: derivedIndex(for: key))
    }
}

extension Store {
    /// An explicit choice wins; otherwise the key's hash decides.
    func color(for key: String) -> Color {
        guard let index = project(key)?.colorIndex else { return Palette.color(for: key) }
        return Palette.color(at: index)
    }
}

// MARK: - Chrome

enum Theme {
    static let cardRadius: CGFloat = 10
    static let rowRadius: CGFloat = 6

    static let card = Color(nsColor: .controlBackgroundColor)
    static let hairline = Color(nsColor: .separatorColor)
    static let window = Color(nsColor: .windowBackgroundColor)
}

extension View {
    /// A raised content panel on the window background.
    func card() -> some View {
        background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .strokeBorder(Theme.hairline.opacity(0.7), lineWidth: 1)
            )
    }

    func hoverHighlight(radius: CGFloat = Theme.rowRadius) -> some View {
        modifier(HoverHighlight(radius: radius))
    }
}

private struct HoverHighlight: ViewModifier {
    let radius: CGFloat
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color.primary.opacity(hovering ? 0.06 : 0))
            )
            .onHover { hovering = $0 }
    }
}

// MARK: - Bars

/// A day's project split, drawn as one capsule. `scale` is the hour count that
/// fills the full width, so rows stay comparable to each other.
struct StackedBar: View {
    @Environment(Store.self) private var store

    let segments: [(key: String, hours: Double)]
    let scale: Double
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 1) {
                ForEach(segments, id: \.key) { segment in
                    store.color(for: segment.key)
                        .frame(width: width(segment.hours, in: geo.size.width))
                }
                Spacer(minLength: 0)
            }
        }
        .frame(height: height)
        .background(Color.primary.opacity(0.07))
        .clipShape(Capsule())
    }

    private func width(_ hours: Double, in total: CGFloat) -> CGFloat {
        guard scale > 0 else { return 0 }
        return max(2, total * CGFloat(hours / scale))
    }
}

/// A single project's share of something, in that project's colour.
struct ShareBar: View {
    @Environment(Store.self) private var store

    let key: String
    let fraction: Double
    var height: CGFloat = 3

    var body: some View {
        GeometryReader { geo in
            Capsule()
                .fill(store.color(for: key))
                .frame(width: max(2, geo.size.width * CGFloat(min(max(fraction, 0), 1))))
        }
        .frame(height: height)
        .background(Color.primary.opacity(0.07))
        .clipShape(Capsule())
    }
}

/// The legend dot that ties a name to its colour everywhere it appears.
struct ProjectDot: View {
    @Environment(Store.self) private var store

    let key: String
    var size: CGFloat = 7
    /// Set while editing, to preview a colour that has not been saved yet.
    var override: Color?

    var body: some View {
        Circle()
            .fill(override ?? store.color(for: key))
            .frame(width: size, height: size)
    }
}
