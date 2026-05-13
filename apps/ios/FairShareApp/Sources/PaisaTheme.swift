import SwiftUI
import UIKit

enum PaisaTheme {
    static let plum = Color(red: 0.43, green: 0.28, blue: 0.78)
    static let teal = Color(red: 0.10, green: 0.61, blue: 0.64)
    static let coral = Color(red: 0.95, green: 0.42, blue: 0.36)
    static let sun = Color(red: 0.96, green: 0.74, blue: 0.24)
    static let leaf = Color(red: 0.24, green: 0.67, blue: 0.43)
    static let ink = adaptiveColor(
        light: UIColor(red: 0.14, green: 0.15, blue: 0.23, alpha: 1),
        dark: UIColor(red: 0.94, green: 0.95, blue: 0.98, alpha: 1)
    )
    static let mist = adaptiveColor(
        light: UIColor(red: 0.96, green: 0.97, blue: 1.00, alpha: 1),
        dark: UIColor(red: 0.07, green: 0.09, blue: 0.14, alpha: 1)
    )
    static let blush = adaptiveColor(
        light: UIColor(red: 1.00, green: 0.95, blue: 0.94, alpha: 1),
        dark: UIColor(red: 0.19, green: 0.12, blue: 0.16, alpha: 1)
    )
    static let mint = adaptiveColor(
        light: UIColor(red: 0.92, green: 0.99, blue: 0.96, alpha: 1),
        dark: UIColor(red: 0.08, green: 0.17, blue: 0.16, alpha: 1)
    )
    static let sky = adaptiveColor(
        light: UIColor(red: 0.92, green: 0.97, blue: 1.00, alpha: 1),
        dark: UIColor(red: 0.09, green: 0.14, blue: 0.22, alpha: 1)
    )
    static let backgroundWash = adaptiveColor(
        light: UIColor.white.withAlphaComponent(0.18),
        dark: UIColor.black.withAlphaComponent(0.18)
    )
    static let fieldFill = adaptiveColor(
        light: UIColor.white.withAlphaComponent(0.58),
        dark: UIColor(red: 0.15, green: 0.17, blue: 0.24, alpha: 0.88)
    )
    static let fieldStroke = adaptiveColor(
        light: UIColor.white.withAlphaComponent(0.38),
        dark: UIColor.white.withAlphaComponent(0.12)
    )
    static let glassStroke = adaptiveColor(
        light: UIColor.white.withAlphaComponent(0.42),
        dark: UIColor.white.withAlphaComponent(0.10)
    )
    static let softSurface = adaptiveColor(
        light: UIColor.white.withAlphaComponent(0.40),
        dark: UIColor.white.withAlphaComponent(0.06)
    )

    static let pageGradient = LinearGradient(
        colors: [mist, sky, blush, mint],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    private static func adaptiveColor(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? dark : light
        })
    }
}

struct PaisaBackground: View {
    var body: some View {
        PaisaTheme.pageGradient
            .overlay(PaisaTheme.backgroundWash)
            .ignoresSafeArea()
    }
}

enum PaisaAppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let storageKey = "paisa.appearance.mode"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

struct PaisaScreen<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            PaisaBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    content
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 30)
            }
        }
    }
}

struct PaisaGlassGroup<Content: View>: View {
    let spacing: CGFloat
    private let content: Content

    init(spacing: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    @ViewBuilder
    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: spacing) {
                content
            }
        } else {
            content
        }
    }
}

struct PaisaPanel<Content: View>: View {
    let cornerRadius: CGFloat
    let tint: Color?
    let interactive: Bool
    let padding: CGFloat
    private let content: Content

    init(
        cornerRadius: CGFloat = 22,
        tint: Color? = nil,
        interactive: Bool = false,
        padding: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.tint = tint
        self.interactive = interactive
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(
                PaisaGlassSurface(
                    cornerRadius: cornerRadius,
                    tint: tint,
                    interactive: interactive
                )
            )
    }
}

struct PaisaMetricTile: View {
    let title: String
    let amount: String
    let tone: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(amount)
                .font(.headline.weight(.semibold))
                .foregroundStyle(tone)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .modifier(
            PaisaGlassSurface(
                cornerRadius: 18,
                tint: tone.opacity(0.16),
                interactive: false
            )
        )
    }
}

struct PaisaSectionHeader: View {
    let title: String
    let subtitle: String?
    let systemImage: String

    init(_ title: String, subtitle: String? = nil, systemImage: String) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            PaisaIconBadge(systemImage: systemImage, tint: PaisaTheme.plum)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(PaisaTheme.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct PaisaIconBadge: View {
    let systemImage: String
    let tint: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 34, height: 34)
            .background(
                Circle()
                    .fill(tint.opacity(0.14))
            )
    }
}

struct PaisaPill: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(tint.opacity(0.14))
            )
    }
}

struct PaisaEmptyState: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        PaisaPanel(tint: PaisaTheme.sky.opacity(0.5)) {
            VStack(alignment: .leading, spacing: 10) {
                PaisaIconBadge(systemImage: systemImage, tint: PaisaTheme.teal)
                Text(title)
                    .font(.headline.weight(.semibold))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct PaisaPrimaryButton: View {
    let title: String
    let systemImage: String
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    init(
        _ title: String,
        systemImage: String,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .tint(PaisaTheme.plum)
        .modifier(PaisaButtonSurface(prominent: true))
        .disabled(isDisabled || isLoading)
    }
}

struct PaisaSecondaryButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    init(_ title: String, systemImage: String, tint: Color = PaisaTheme.teal, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .labelStyle(.titleAndIcon)
        }
        .tint(tint)
        .modifier(PaisaButtonSurface(prominent: false))
    }
}

struct PaisaFieldLabel<Content: View>: View {
    let title: String
    private let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            content
        }
    }
}

extension View {
    func paisaTextField() -> some View {
        padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(PaisaTheme.fieldFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(PaisaTheme.fieldStroke, lineWidth: 1)
            }
    }
}

private struct PaisaGlassSurface: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color?
    let interactive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .glassEffect(
                    .regular
                        .tint(tint)
                        .interactive(interactive),
                    in: .rect(cornerRadius: cornerRadius)
                )
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(PaisaTheme.glassStroke, lineWidth: 1)
                }
        }
    }
}

private struct PaisaButtonSurface: ViewModifier {
    let prominent: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            if prominent {
                content.buttonStyle(.glassProminent)
            } else {
                content.buttonStyle(.glass)
            }
        } else {
            if prominent {
                content.buttonStyle(.borderedProminent)
            } else {
                content.buttonStyle(.bordered)
            }
        }
    }
}
