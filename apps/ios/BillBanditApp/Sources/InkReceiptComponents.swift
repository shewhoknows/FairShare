import SwiftUI
import UIKit

enum InkReceiptTheme {
    static let receiptCream = adaptiveColor(
        light: UIColor(red: 1.00, green: 0.96, blue: 0.87, alpha: 1.00),
        dark: UIColor(red: 0.12, green: 0.13, blue: 0.18, alpha: 1.00)
    )
    static let receiptPaper = adaptiveColor(
        light: UIColor(red: 0.97, green: 0.95, blue: 0.87, alpha: 1.00),
        dark: UIColor(red: 0.16, green: 0.17, blue: 0.23, alpha: 1.00)
    )
    static let finalStampWhite = adaptiveColor(
        light: UIColor(red: 0.97, green: 0.95, blue: 0.87, alpha: 1.00),
        dark: UIColor(red: 0.23, green: 0.24, blue: 0.31, alpha: 1.00)
    )
    static let structureInk = adaptiveColor(
        light: UIColor(red: 0.03, green: 0.17, blue: 0.56, alpha: 1.00),
        dark: UIColor(red: 0.62, green: 0.73, blue: 1.00, alpha: 1.00)
    )
    static let rupeeBlue = adaptiveColor(
        light: UIColor(red: 0.06, green: 0.27, blue: 0.84, alpha: 1.00),
        dark: UIColor(red: 0.38, green: 0.57, blue: 1.00, alpha: 1.00)
    )
    static let settledGreen = adaptiveColor(
        light: UIColor(red: 0.12, green: 0.56, blue: 0.40, alpha: 1.00),
        dark: UIColor(red: 0.38, green: 0.84, blue: 0.65, alpha: 1.00)
    )
    static let dangerInk = adaptiveColor(
        light: UIColor(red: 0.66, green: 0.12, blue: 0.20, alpha: 1.00),
        dark: UIColor(red: 1.00, green: 0.48, blue: 0.56, alpha: 1.00)
    )
    static let fadedInk = adaptiveColor(
        light: UIColor(red: 0.33, green: 0.39, blue: 0.55, alpha: 1.00),
        dark: UIColor(red: 0.70, green: 0.74, blue: 0.84, alpha: 1.00)
    )
    static let dividerInk = adaptiveColor(
        light: UIColor(red: 0.03, green: 0.17, blue: 0.56, alpha: 0.20),
        dark: UIColor(red: 0.62, green: 0.73, blue: 1.00, alpha: 0.24)
    )

    static let receiptShadow = Color.black.opacity(0.08)

    static let titleFont = Font.system(.title3, design: .serif).weight(.bold)
    static let sectionFont = Font.system(.subheadline, design: .monospaced).weight(.semibold)
    static let amountFont = Font.system(.headline, design: .monospaced).weight(.bold)
    static let labelFont = Font.system(.caption, design: .monospaced).weight(.semibold)
    static let bodyFont = Font.system(.subheadline, design: .rounded)

    private static func adaptiveColor(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

struct ReceiptCard<Content: View>: View {
    let eyebrow: String?
    let title: String?
    let subtitle: String?
    let barcodeValue: String?
    let showsPerforatedEdges: Bool
    let content: Content

    init(
        eyebrow: String? = nil,
        title: String? = nil,
        subtitle: String? = nil,
        barcodeValue: String? = nil,
        showsPerforatedEdges: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.barcodeValue = barcodeValue
        self.showsPerforatedEdges = showsPerforatedEdges
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if hasHeader {
                receiptHeader
                PerforationDivider()
            }

            content

            if let barcodeValue {
                PerforationDivider()
                Barcode(value: barcodeValue)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(InkReceiptTheme.receiptPaper)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    InkReceiptTheme.structureInk.opacity(0.28),
                    style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                )
        }
        .shadow(color: InkReceiptTheme.receiptShadow, radius: 18, x: 0, y: 10)
        .modifier(
            ReceiptEdgeTreatment(
                isEnabled: showsPerforatedEdges,
                holeColor: InkReceiptTheme.receiptCream
            )
        )
    }

    private var hasHeader: Bool {
        eyebrow != nil || title != nil || subtitle != nil
    }

    private var receiptHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let eyebrow {
                Text(eyebrow.uppercased())
                    .font(InkReceiptTheme.labelFont)
                    .foregroundStyle(InkReceiptTheme.rupeeBlue)
                    .tracking(1.2)
            }

            if let title {
                Text(title)
                    .font(InkReceiptTheme.titleFont)
                    .foregroundStyle(InkReceiptTheme.structureInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let subtitle {
                Text(subtitle)
                    .font(InkReceiptTheme.bodyFont)
                    .foregroundStyle(InkReceiptTheme.fadedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct ReceiptEdgeTreatment: ViewModifier {
    var isEnabled = true
    var holeColor = InkReceiptTheme.receiptCream
    var notchDiameter: CGFloat = 12
    var spacing: CGFloat = 22

    func body(content: Content) -> some View {
        content.overlay {
            if isEnabled {
                GeometryReader { proxy in
                    let count = max(2, Int(proxy.size.height / spacing))
                    let step = proxy.size.height / CGFloat(count + 1)

                    ZStack {
                        ForEach(1...count, id: \.self) { index in
                            Circle()
                                .fill(holeColor)
                                .frame(width: notchDiameter, height: notchDiameter)
                                .position(x: 0, y: CGFloat(index) * step)

                            Circle()
                                .fill(holeColor)
                                .frame(width: notchDiameter, height: notchDiameter)
                                .position(x: proxy.size.width, y: CGFloat(index) * step)
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
        }
    }
}

struct PerforationDivider: View {
    var color = InkReceiptTheme.dividerInk

    var body: some View {
        Line()
            .stroke(color, style: StrokeStyle(lineWidth: 1, dash: [3, 5], dashPhase: 1))
            .frame(height: 1)
            .accessibilityHidden(true)
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        }
    }
}

struct Stamp: View {
    let text: String
    var systemImage: String?
    var tone = InkReceiptTheme.rupeeBlue
    var rotation: Angle = .degrees(-6)

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .imageScale(.small)
            }

            Text(text.uppercased())
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .font(.system(.caption, design: .monospaced).weight(.heavy))
        .tracking(1.1)
        .foregroundStyle(tone)
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(InkReceiptTheme.finalStampWhite, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(tone, style: StrokeStyle(lineWidth: 2, dash: [6, 3]))
        }
        .rotationEffect(rotation)
        .accessibilityLabel(text)
    }
}

struct Seal: View {
    let title: String
    var caption: String?
    var tone = InkReceiptTheme.structureInk
    var diameter: CGFloat = 78

    var body: some View {
        ZStack {
            Circle()
                .fill(InkReceiptTheme.finalStampWhite)

            Circle()
                .stroke(tone, lineWidth: 2)
                .padding(3)

            Circle()
                .stroke(tone.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [2, 4]))
                .padding(9)

            VStack(spacing: 2) {
                Text(title.uppercased())
                    .font(.system(size: 14, weight: .heavy, design: .monospaced))
                    .tracking(1.1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                if let caption {
                    Text(caption.uppercased())
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .tracking(0.8)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .foregroundStyle(tone)
            .padding(.horizontal, 10)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .combine)
    }
}

struct Barcode: View {
    let value: String
    var height: CGFloat = 42
    var ink = InkReceiptTheme.structureInk

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(widths.enumerated()), id: \.offset) { _, width in
                    RoundedRectangle(cornerRadius: 0.8)
                        .fill(ink)
                        .frame(width: width, height: height)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
            .accessibilityHidden(true)

            Text(value.uppercased())
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(InkReceiptTheme.fadedInk)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .accessibilityLabel("Barcode \(value)")
    }

    private var widths: [CGFloat] {
        let scalars = value.isEmpty ? Array("BILLBANDIT".unicodeScalars) : Array(value.unicodeScalars)
        let base = scalars.flatMap { scalar -> [CGFloat] in
            let number = Int(scalar.value)
            return [
                CGFloat((number % 3) + 1),
                CGFloat(((number / 3) % 4) + 1),
                CGFloat(((number / 7) % 2) + 1)
            ]
        }

        return Array((base + [1, 3, 1, 2, 4, 1]).prefix(48))
    }
}

enum InkButtonVariant {
    case primary
    case secondary
    case quiet
    case destructive
}

struct InkButton: View {
    let title: String
    var systemImage: String?
    var variant: InkButtonVariant = .primary
    var isLoading = false
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                if isLoading {
                    ProgressView()
                        .tint(progressTint)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .imageScale(.medium)
                }

                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .font(.system(.subheadline, design: .rounded).weight(.bold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(border, lineWidth: borderWidth)
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.58 : 1)
        .accessibilityLabel(title)
    }

    private var foreground: Color {
        switch variant {
        case .primary, .destructive:
            InkReceiptTheme.receiptCream
        case .secondary:
            InkReceiptTheme.structureInk
        case .quiet:
            InkReceiptTheme.rupeeBlue
        }
    }

    private var background: Color {
        switch variant {
        case .primary:
            InkReceiptTheme.structureInk
        case .secondary:
            InkReceiptTheme.receiptPaper
        case .quiet:
            InkReceiptTheme.rupeeBlue.opacity(0.10)
        case .destructive:
            InkReceiptTheme.dangerInk
        }
    }

    private var border: Color {
        switch variant {
        case .primary:
            InkReceiptTheme.structureInk
        case .secondary:
            InkReceiptTheme.structureInk.opacity(0.38)
        case .quiet:
            InkReceiptTheme.rupeeBlue.opacity(0.18)
        case .destructive:
            InkReceiptTheme.dangerInk
        }
    }

    private var borderWidth: CGFloat {
        variant == .secondary ? 1.2 : 0
    }

    private var progressTint: Color {
        variant == .primary || variant == .destructive ? InkReceiptTheme.receiptCream : InkReceiptTheme.structureInk
    }
}

struct Chip: View {
    let title: String
    var systemImage: String?
    var isSelected = false
    var tone = InkReceiptTheme.rupeeBlue
    var action: (() -> Void)?

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    chipContent
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            } else {
                chipContent
            }
        }
    }

    private var chipContent: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .imageScale(.small)
            }

            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .font(InkReceiptTheme.labelFont)
        .foregroundStyle(isSelected ? InkReceiptTheme.receiptCream : tone)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(isSelected ? tone : tone.opacity(0.11), in: Capsule())
        .overlay {
            Capsule()
                .stroke(tone.opacity(isSelected ? 0 : 0.28), lineWidth: 1)
        }
    }
}

struct InkTabItem<Selection: Hashable>: Identifiable, Hashable {
    let id: Selection
    let title: String
    let systemImage: String
    let badge: String?

    init(id: Selection, title: String, systemImage: String, badge: String? = nil) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.badge = badge
    }
}

struct BottomTabs<Selection: Hashable>: View {
    let tabs: [InkTabItem<Selection>]
    @Binding var selection: Selection

    var body: some View {
        HStack(spacing: 6) {
            ForEach(tabs) { tab in
                Button {
                    selection = tab.id
                } label: {
                    VStack(spacing: 4) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: tab.systemImage)
                                .font(.system(size: 17, weight: .semibold))

                            if let badge = tab.badge {
                                Text(badge)
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(InkReceiptTheme.receiptCream)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(InkReceiptTheme.dangerInk, in: Capsule())
                                    .offset(x: 13, y: -8)
                            }
                        }

                        Text(tab.title)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(selection == tab.id ? InkReceiptTheme.structureInk : InkReceiptTheme.fadedInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        selection == tab.id ? InkReceiptTheme.rupeeBlue.opacity(0.12) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selection == tab.id ? .isSelected : [])
            }
        }
        .padding(6)
        .background(InkReceiptTheme.receiptPaper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(InkReceiptTheme.structureInk.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: InkReceiptTheme.receiptShadow, radius: 14, x: 0, y: 6)
    }
}

struct Field: View {
    let title: String
    var placeholder: String = ""
    @Binding var text: String
    var systemImage: String?
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType?
    var axis: Axis = .horizontal

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title.uppercased())
                .font(InkReceiptTheme.labelFont)
                .tracking(0.8)
                .foregroundStyle(InkReceiptTheme.fadedInk)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .foregroundStyle(InkReceiptTheme.rupeeBlue)
                        .frame(width: 18)
                }

                TextField(placeholder, text: $text, axis: axis)
                    .font(InkReceiptTheme.bodyFont)
                    .foregroundStyle(InkReceiptTheme.structureInk)
                    .keyboardType(keyboardType)
                    .textContentType(textContentType)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(InkReceiptTheme.finalStampWhite, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(InkReceiptTheme.structureInk.opacity(0.26), lineWidth: 1)
            }
        }
    }
}

enum InkAmountTone {
    case credit
    case debit
    case neutral
    case warning

    var color: Color {
        switch self {
        case .credit:
            InkReceiptTheme.settledGreen
        case .debit:
            InkReceiptTheme.dangerInk
        case .neutral:
            InkReceiptTheme.structureInk
        case .warning:
            InkReceiptTheme.rupeeBlue
        }
    }
}

struct EntryRow: View {
    let title: String
    var subtitle: String?
    var detail: String?
    var amount: String?
    var amountTone: InkAmountTone = .neutral
    var systemImage: String = "list.bullet.rectangle"

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(InkReceiptTheme.rupeeBlue)
                .frame(width: 34, height: 34)
                .background(InkReceiptTheme.rupeeBlue.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(InkReceiptTheme.structureInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(InkReceiptTheme.fadedInk)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 10)

            VStack(alignment: .trailing, spacing: 3) {
                if let amount {
                    Text(amount)
                        .font(InkReceiptTheme.amountFont)
                        .foregroundStyle(amountTone.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                if let detail {
                    Text(detail.uppercased())
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(InkReceiptTheme.fadedInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

enum TransactionRowKind {
    case paid
    case received
    case settled
    case pending

    var title: String {
        switch self {
        case .paid:
            "Paid"
        case .received:
            "Received"
        case .settled:
            "Settled"
        case .pending:
            "Pending"
        }
    }

    var icon: String {
        switch self {
        case .paid:
            "arrow.up.right.circle.fill"
        case .received:
            "arrow.down.left.circle.fill"
        case .settled:
            "checkmark.seal.fill"
        case .pending:
            "clock.fill"
        }
    }

    var tone: InkAmountTone {
        switch self {
        case .paid:
            .debit
        case .received, .settled:
            .credit
        case .pending:
            .warning
        }
    }
}

struct TransactionRow: View {
    let payer: String
    let receiver: String
    let amount: String
    var date: String?
    var note: String?
    var kind: TransactionRowKind = .pending

    var body: some View {
        EntryRow(
            title: "\(payer) -> \(receiver)",
            subtitle: note,
            detail: date ?? kind.title,
            amount: amount,
            amountTone: kind.tone,
            systemImage: kind.icon
        )
    }
}

#Preview("Ink Receipt Components") {
    @Previewable @State var selectedTab = "ledger"
    @Previewable @State var memo = "Dinner split"

    ScrollView {
        VStack(spacing: 18) {
            ReceiptCard(
                eyebrow: "BillBandit closeout",
                title: "Trip ledger",
                subtitle: "Receipt-style components ready for dashboard, group detail, and settlement flows.",
                barcodeValue: "FS-2026-0616"
            ) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Stamp(text: "Paid", systemImage: "checkmark")
                        Spacer()
                        Seal(title: "Final", caption: "Clear")
                    }

                    EntryRow(
                        title: "Weekend stay",
                        subtitle: "Paid by Asha",
                        detail: "Split",
                        amount: "INR 4,200",
                        amountTone: .neutral,
                        systemImage: "receipt.fill"
                    )

                    TransactionRow(
                        payer: "Rahul",
                        receiver: "Asha",
                        amount: "INR 1,400",
                        date: "Today",
                        note: "UPI settlement",
                        kind: .settled
                    )

                    Field(title: "Memo", placeholder: "Add note", text: $memo, systemImage: "text.alignleft")

                    HStack {
                        Chip(title: "Equal", systemImage: "person.2.fill", isSelected: true)
                        Chip(title: "Exact", systemImage: "number")
                        Chip(title: "Shares", systemImage: "chart.pie")
                    }

                    InkButton(title: "Settle balance", systemImage: "arrow.left.arrow.right.circle.fill") {}
                }
            }

            BottomTabs(
                tabs: [
                    InkTabItem(id: "home", title: "Home", systemImage: "house"),
                    InkTabItem(id: "ledger", title: "Ledger", systemImage: "receipt", badge: "3"),
                    InkTabItem(id: "account", title: "Account", systemImage: "person.crop.circle")
                ],
                selection: $selectedTab
            )
        }
        .padding(18)
    }
    .background(InkReceiptTheme.receiptCream)
}
