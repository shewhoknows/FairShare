import SwiftUI

struct MascotWelcome: View {
    var size: CGFloat = 176

    var body: some View {
        MascotAssetImage(name: "MascotWelcome", size: size)
            .accessibilityLabel("BillBandit welcome mascot")
    }
}

struct MascotPeek: View {
    var size: CGFloat = 176

    var body: some View {
        MascotAssetImage(name: "MascotPeek", size: size)
            .accessibilityLabel("BillBandit peek mascot")
    }
}

struct MascotThinking: View {
    var size: CGFloat = 176

    var body: some View {
        MascotAssetImage(name: "MascotThinking", size: size)
            .accessibilityLabel("BillBandit thinking mascot")
    }
}

struct MascotFinal: View {
    var size: CGFloat = 176

    var body: some View {
        MascotAssetImage(name: "MascotFinal", size: size)
            .accessibilityLabel("BillBandit final mascot")
    }
}

struct MascotStamp: View {
    var size: CGFloat = 176

    var body: some View {
        MascotAssetImage(name: "MascotBadge", size: size)
            .accessibilityLabel("BillBandit stamp mascot")
    }
}

struct MascotLedger: View {
    var size: CGFloat = 176

    var body: some View {
        MascotAssetImage(name: "MascotLedger", size: size)
            .accessibilityLabel("BillBandit ledger mascot")
    }
}

struct FinalStampAsset: View {
    var width: CGFloat = 80

    var body: some View {
        Image("StampFinal")
            .resizable()
            .scaledToFit()
            .frame(width: width)
            .accessibilityLabel("Final stamp")
    }
}

private struct MascotAssetImage: View {
    let name: String
    let size: CGFloat

    var body: some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}

private enum BillBanditMascotPose {
    case welcome
    case peek
    case thinking
    case final
    case stamp
}

private struct BillBanditMascotScene: View {
    let size: CGFloat
    let pose: BillBanditMascotPose

    private var faceYOffset: CGFloat {
        switch pose {
        case .peek: 20
        case .stamp: -4
        default: 0
        }
    }

    private var faceRotation: Angle {
        switch pose {
        case .thinking: .degrees(-4)
        case .final: .degrees(3)
        case .peek: .degrees(-2)
        default: .degrees(0)
        }
    }

    var body: some View {
        ZStack {
            BillBanditMascotBackdrop(pose: pose)

            if pose == .thinking {
                MascotThoughtBubbles()
                    .frame(width: size * 0.42, height: size * 0.30)
                    .offset(x: size * 0.24, y: -size * 0.34)
            }

            if pose == .final {
                MascotFinalReceipt()
                    .frame(width: size * 0.44, height: size * 0.56)
                    .offset(x: size * 0.28, y: size * 0.10)
                    .rotationEffect(.degrees(8))
                    .zIndex(3)
            }

            if pose == .stamp {
                MascotStampMark()
                    .frame(width: size * 0.58, height: size * 0.40)
                    .offset(y: size * 0.30)
                    .rotationEffect(.degrees(-7))
                    .zIndex(5)
            }

            if pose != .peek && pose != .stamp {
                MascotTail()
                    .frame(width: size * 0.40, height: size * 0.52)
                    .offset(x: size * 0.28, y: size * 0.24)
                    .rotationEffect(pose == .thinking ? .degrees(-7) : .degrees(0))
                    .zIndex(0)
            }

            MascotBody(pose: pose)
                .frame(width: size * 0.62, height: size * 0.48)
                .offset(y: size * 0.28)
                .zIndex(1)

            MascotHead(pose: pose)
                .frame(width: size * 0.72, height: size * 0.66)
                .rotationEffect(faceRotation)
                .offset(y: faceYOffset)
                .zIndex(2)

            MascotArms(pose: pose)
                .frame(width: size * 0.82, height: size * 0.54)
                .offset(y: size * 0.16)
                .zIndex(3)
        }
        .frame(width: size, height: size)
        .drawingGroup()
    }
}

private enum BillBanditMascotPalette {
    static let ink = Color(red: 0.96, green: 0.94, blue: 0.88)
    static let inkSoft = Color(red: 0.93, green: 0.89, blue: 0.78)
    static let blue = Color(red: 0.13, green: 0.19, blue: 0.90)
    static let blueDark = Color(red: 0.07, green: 0.11, blue: 0.42)
    static let bluePale = Color.clear
    static let receipt = Color(red: 0.96, green: 0.94, blue: 0.88)
    static let receiptShadow = Color(red: 0.13, green: 0.19, blue: 0.90).opacity(0.36)
    static let fur = Color(red: 0.96, green: 0.94, blue: 0.88)
    static let furLight = Color(red: 0.96, green: 0.94, blue: 0.88)
    static let mask = Color(red: 0.13, green: 0.19, blue: 0.90)
    static let blush = Color.clear
}

private struct BillBanditMascotBackdrop: View {
    let pose: BillBanditMascotPose

    var body: some View {
        Color.clear
    }
}

private struct MascotHead: View {
    let pose: BillBanditMascotPose

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let scale = min(width, height) / 128

            ZStack {
                ear(x: 24, y: 28, scale: scale, rotation: -18)
                ear(x: 104, y: 28, scale: scale, rotation: 18)

                Ellipse()
                    .fill(BillBanditMascotPalette.fur)
                    .frame(width: 102 * scale, height: 90 * scale)
                    .overlay {
                        Ellipse()
                            .stroke(BillBanditMascotPalette.ink, lineWidth: 3 * scale)
                    }
                    .position(x: width / 2, y: 66 * scale)

                MaskStripe()
                    .fill(BillBanditMascotPalette.mask)
                    .frame(width: 88 * scale, height: 34 * scale)
                    .position(x: width / 2, y: 60 * scale)

                EyePair(pose: pose)
                    .frame(width: 58 * scale, height: 19 * scale)
                    .position(x: width / 2, y: 58 * scale)

                Ellipse()
                    .fill(BillBanditMascotPalette.furLight)
                    .frame(width: 58 * scale, height: 42 * scale)
                    .overlay {
                        Ellipse()
                            .stroke(BillBanditMascotPalette.ink.opacity(0.18), lineWidth: 1.4 * scale)
                    }
                    .position(x: width / 2, y: 84 * scale)

                NoseAndMouth(pose: pose)
                    .frame(width: 30 * scale, height: 22 * scale)
                    .position(x: width / 2, y: 78 * scale)

                Circle()
                    .fill(BillBanditMascotPalette.blush.opacity(0.34))
                    .frame(width: 10 * scale, height: 10 * scale)
                    .position(x: 39 * scale, y: 79 * scale)

                Circle()
                    .fill(BillBanditMascotPalette.blush.opacity(0.34))
                    .frame(width: 10 * scale, height: 10 * scale)
                    .position(x: 89 * scale, y: 79 * scale)

                if pose == .welcome {
                    MascotSpark()
                        .stroke(BillBanditMascotPalette.blue, style: StrokeStyle(lineWidth: 2 * scale, lineCap: .round))
                        .frame(width: 14 * scale, height: 14 * scale)
                        .position(x: 101 * scale, y: 19 * scale)
                }
            }
        }
    }

    private func ear(x: CGFloat, y: CGFloat, scale: CGFloat, rotation: Double) -> some View {
        ZStack {
            Triangle()
                .fill(BillBanditMascotPalette.fur)
                .frame(width: 28 * scale, height: 31 * scale)
                .overlay {
                    Triangle()
                        .stroke(BillBanditMascotPalette.ink, lineWidth: 3 * scale)
                }

            Triangle()
                .fill(BillBanditMascotPalette.furLight.opacity(0.82))
                .frame(width: 13 * scale, height: 15 * scale)
                .offset(y: 3 * scale)
        }
        .rotationEffect(.degrees(rotation))
        .position(x: x * scale, y: y * scale)
    }
}

private struct MascotBody: View {
    let pose: BillBanditMascotPose

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width, proxy.size.height) / 92
            let width = proxy.size.width

            ZStack {
                RoundedRectangle(cornerRadius: 30 * scale, style: .continuous)
                    .fill(BillBanditMascotPalette.fur)
                    .frame(width: 74 * scale, height: 74 * scale)
                    .overlay {
                        RoundedRectangle(cornerRadius: 30 * scale, style: .continuous)
                            .stroke(BillBanditMascotPalette.ink, lineWidth: 3 * scale)
                    }
                    .position(x: width / 2, y: 46 * scale)

                RoundedRectangle(cornerRadius: 22 * scale, style: .continuous)
                    .fill(BillBanditMascotPalette.receipt)
                    .frame(width: 48 * scale, height: 44 * scale)
                    .overlay {
                        VStack(spacing: 4 * scale) {
                            Capsule().fill(BillBanditMascotPalette.blue.opacity(0.62))
                            Capsule().fill(BillBanditMascotPalette.receiptShadow.opacity(0.62))
                            Capsule().fill(BillBanditMascotPalette.receiptShadow.opacity(0.46))
                        }
                        .padding(.horizontal, 12 * scale)
                        .padding(.vertical, 10 * scale)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 22 * scale, style: .continuous)
                            .stroke(BillBanditMascotPalette.ink.opacity(0.18), lineWidth: 1.4 * scale)
                    }
                    .position(x: width / 2, y: 51 * scale)

                if pose == .final {
                    Circle()
                        .fill(BillBanditMascotPalette.blue)
                        .frame(width: 16 * scale, height: 16 * scale)
                        .overlay {
                            Checkmark()
                                .stroke(.white, style: StrokeStyle(lineWidth: 2.2 * scale, lineCap: .round, lineJoin: .round))
                                .padding(4 * scale)
                        }
                        .position(x: 66 * scale, y: 25 * scale)
                }
            }
        }
    }
}

private struct MascotTail: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack {
                TailShape()
                    .fill(BillBanditMascotPalette.fur)

                VStack(spacing: height * 0.07) {
                    ForEach(0..<3, id: \.self) { index in
                        Capsule()
                            .fill(BillBanditMascotPalette.mask)
                            .frame(width: width * (index == 0 ? 0.64 : 0.78), height: height * 0.12)
                            .rotationEffect(.degrees(-18))
                    }
                }
                .offset(x: width * 0.10, y: height * 0.05)
                .mask(TailShape())

                TailShape()
                    .stroke(BillBanditMascotPalette.ink, style: StrokeStyle(lineWidth: max(width * 0.055, 2.4), lineCap: .round, lineJoin: .round))
            }
        }
    }
}

private struct TailShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.20, y: rect.maxY * 0.88))
        path.addCurve(
            to: CGPoint(x: rect.maxX * 0.88, y: rect.minY + rect.height * 0.30),
            control1: CGPoint(x: rect.maxX * 0.08, y: rect.maxY * 0.58),
            control2: CGPoint(x: rect.maxX * 0.30, y: rect.minY + rect.height * 0.12)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX * 0.58, y: rect.maxY * 0.88),
            control1: CGPoint(x: rect.maxX * 1.05, y: rect.minY + rect.height * 0.58),
            control2: CGPoint(x: rect.maxX * 0.95, y: rect.maxY * 0.92)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.20, y: rect.maxY * 0.88),
            control1: CGPoint(x: rect.maxX * 0.43, y: rect.maxY * 0.72),
            control2: CGPoint(x: rect.maxX * 0.30, y: rect.maxY * 0.84)
        )
        path.closeSubpath()
        return path
    }
}

private struct MascotArms: View {
    let pose: BillBanditMascotPose

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width, proxy.size.height) / 118

            ZStack {
                switch pose {
                case .welcome:
                    ArmPath(side: .left, pose: .welcome)
                        .stroke(BillBanditMascotPalette.ink, style: StrokeStyle(lineWidth: 14 * scale, lineCap: .round))
                    ArmPath(side: .left, pose: .welcome)
                        .stroke(BillBanditMascotPalette.fur, style: StrokeStyle(lineWidth: 9 * scale, lineCap: .round))
                    ArmPath(side: .right, pose: .welcome)
                        .stroke(BillBanditMascotPalette.ink, style: StrokeStyle(lineWidth: 14 * scale, lineCap: .round))
                    ArmPath(side: .right, pose: .welcome)
                        .stroke(BillBanditMascotPalette.fur, style: StrokeStyle(lineWidth: 9 * scale, lineCap: .round))

                case .peek:
                    Paw(x: 32 * scale, y: 91 * scale, scale: scale)
                    Paw(x: 86 * scale, y: 91 * scale, scale: scale)

                case .thinking:
                    ArmPath(side: .left, pose: .thinking)
                        .stroke(BillBanditMascotPalette.ink, style: StrokeStyle(lineWidth: 14 * scale, lineCap: .round))
                    ArmPath(side: .left, pose: .thinking)
                        .stroke(BillBanditMascotPalette.fur, style: StrokeStyle(lineWidth: 9 * scale, lineCap: .round))
                    Paw(x: 78 * scale, y: 60 * scale, scale: scale)

                case .final:
                    ArmPath(side: .left, pose: .final)
                        .stroke(BillBanditMascotPalette.ink, style: StrokeStyle(lineWidth: 14 * scale, lineCap: .round))
                    ArmPath(side: .left, pose: .final)
                        .stroke(BillBanditMascotPalette.fur, style: StrokeStyle(lineWidth: 9 * scale, lineCap: .round))
                    Paw(x: 86 * scale, y: 69 * scale, scale: scale)

                case .stamp:
                    ArmPath(side: .left, pose: .stamp)
                        .stroke(BillBanditMascotPalette.ink, style: StrokeStyle(lineWidth: 15 * scale, lineCap: .round))
                    ArmPath(side: .left, pose: .stamp)
                        .stroke(BillBanditMascotPalette.fur, style: StrokeStyle(lineWidth: 10 * scale, lineCap: .round))
                    ArmPath(side: .right, pose: .stamp)
                        .stroke(BillBanditMascotPalette.ink, style: StrokeStyle(lineWidth: 15 * scale, lineCap: .round))
                    ArmPath(side: .right, pose: .stamp)
                        .stroke(BillBanditMascotPalette.fur, style: StrokeStyle(lineWidth: 10 * scale, lineCap: .round))
                }
            }
        }
    }
}

private enum MascotArmSide {
    case left
    case right
}

private struct ArmPath: Shape {
    let side: MascotArmSide
    let pose: BillBanditMascotPose

    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 118
        let sy = rect.height / 118
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: x * sx, y: y * sy)
        }

        var path = Path()
        switch (side, pose) {
        case (.left, .welcome):
            path.move(to: point(39, 61))
            path.addQuadCurve(to: point(20, 30), control: point(22, 58))
        case (.right, .welcome):
            path.move(to: point(79, 61))
            path.addQuadCurve(to: point(101, 28), control: point(99, 55))
        case (.left, .thinking):
            path.move(to: point(39, 68))
            path.addQuadCurve(to: point(55, 83), control: point(42, 89))
        case (.right, .thinking):
            path.move(to: point(76, 66))
            path.addQuadCurve(to: point(82, 50), control: point(91, 60))
        case (.left, .final):
            path.move(to: point(40, 66))
            path.addQuadCurve(to: point(26, 82), control: point(27, 64))
        case (.right, .final):
            path.move(to: point(75, 66))
            path.addQuadCurve(to: point(91, 70), control: point(86, 62))
        case (.left, .stamp):
            path.move(to: point(42, 67))
            path.addQuadCurve(to: point(42, 93), control: point(26, 78))
        case (.right, .stamp):
            path.move(to: point(76, 67))
            path.addQuadCurve(to: point(76, 93), control: point(92, 78))
        default:
            path.move(to: point(39, 68))
            path.addQuadCurve(to: point(55, 83), control: point(42, 89))
        }
        return path
    }
}

private struct Paw: View {
    let x: CGFloat
    let y: CGFloat
    let scale: CGFloat

    var body: some View {
        Ellipse()
            .fill(BillBanditMascotPalette.fur)
            .frame(width: 21 * scale, height: 16 * scale)
            .overlay {
                Ellipse()
                    .stroke(BillBanditMascotPalette.ink, lineWidth: 2.4 * scale)
            }
            .position(x: x, y: y)
    }
}

private struct EyePair: View {
    let pose: BillBanditMascotPose

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width, proxy.size.height) / 19

            ZStack {
                eye(isLeft: true, scale: scale)
                    .position(x: 13 * scale, y: 9 * scale)
                eye(isLeft: false, scale: scale)
                    .position(x: 45 * scale, y: 9 * scale)
            }
        }
    }

    @ViewBuilder
    private func eye(isLeft: Bool, scale: CGFloat) -> some View {
        switch pose {
        case .thinking where !isLeft:
            Wink()
                .stroke(.white, style: StrokeStyle(lineWidth: 2.4 * scale, lineCap: .round))
                .frame(width: 13 * scale, height: 8 * scale)
        case .peek:
            Circle()
                .fill(.white)
                .frame(width: 14 * scale, height: 14 * scale)
                .overlay {
                    Circle()
                        .fill(BillBanditMascotPalette.ink)
                        .frame(width: 8 * scale, height: 8 * scale)
                        .offset(y: 1 * scale)
                }
        default:
            Circle()
                .fill(.white)
                .frame(width: 15 * scale, height: 15 * scale)
                .overlay {
                    Circle()
                        .fill(BillBanditMascotPalette.ink)
                        .frame(width: 8 * scale, height: 8 * scale)
                }
                .overlay(alignment: .topLeading) {
                    Circle()
                        .fill(.white.opacity(0.88))
                        .frame(width: 3.5 * scale, height: 3.5 * scale)
                        .offset(x: 4 * scale, y: 4 * scale)
                }
        }
    }
}

private struct NoseAndMouth: View {
    let pose: BillBanditMascotPose

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width, proxy.size.height) / 22

            ZStack {
                RoundedTriangle()
                    .fill(BillBanditMascotPalette.ink)
                    .frame(width: 10 * scale, height: 7 * scale)
                    .position(x: 15 * scale, y: 5 * scale)

                Mouth(pose: pose)
                    .stroke(BillBanditMascotPalette.ink, style: StrokeStyle(lineWidth: 2 * scale, lineCap: .round, lineJoin: .round))
                    .frame(width: 22 * scale, height: 13 * scale)
                    .position(x: 15 * scale, y: 14 * scale)
            }
        }
    }
}

private struct Mouth: Shape {
    let pose: BillBanditMascotPose

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch pose {
        case .thinking:
            path.move(to: CGPoint(x: rect.midX - rect.width * 0.18, y: rect.midY + rect.height * 0.08))
            path.addLine(to: CGPoint(x: rect.midX + rect.width * 0.18, y: rect.midY + rect.height * 0.08))
        case .final:
            path.move(to: CGPoint(x: rect.midX - rect.width * 0.26, y: rect.midY - rect.height * 0.02))
            path.addQuadCurve(
                to: CGPoint(x: rect.midX + rect.width * 0.26, y: rect.midY - rect.height * 0.02),
                control: CGPoint(x: rect.midX, y: rect.midY + rect.height * 0.40)
            )
        default:
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addQuadCurve(
                to: CGPoint(x: rect.midX - rect.width * 0.30, y: rect.midY + rect.height * 0.18),
                control: CGPoint(x: rect.midX - rect.width * 0.12, y: rect.midY + rect.height * 0.30)
            )
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addQuadCurve(
                to: CGPoint(x: rect.midX + rect.width * 0.30, y: rect.midY + rect.height * 0.18),
                control: CGPoint(x: rect.midX + rect.width * 0.12, y: rect.midY + rect.height * 0.30)
            )
        }
        return path
    }
}

private struct MascotReceiptStrip: View {
    var body: some View {
        ZStack {
            ReceiptShape(teeth: 8)
                .fill(BillBanditMascotPalette.receipt)
                .shadow(color: BillBanditMascotPalette.ink.opacity(0.12), radius: 8, x: 0, y: 5)
                .overlay {
                    ReceiptShape(teeth: 8)
                        .stroke(BillBanditMascotPalette.ink.opacity(0.20), lineWidth: 1.5)
                }

            HStack(spacing: 8) {
                Capsule()
                    .fill(BillBanditMascotPalette.blue)
                    .frame(width: 34, height: 8)
                Capsule()
                    .fill(BillBanditMascotPalette.receiptShadow)
                    .frame(width: 22, height: 8)
                Circle()
                    .fill(BillBanditMascotPalette.blue.opacity(0.26))
                    .frame(width: 8, height: 8)
            }
            .padding(.top, 3)
        }
    }
}

private struct MascotFinalReceipt: View {
    var body: some View {
        ZStack {
            ReceiptShape(teeth: 6)
                .fill(BillBanditMascotPalette.receipt)
                .overlay {
                    ReceiptShape(teeth: 6)
                        .stroke(BillBanditMascotPalette.ink.opacity(0.22), lineWidth: 1.5)
                }

            VStack(spacing: 6) {
                Capsule()
                    .fill(BillBanditMascotPalette.blue)
                    .frame(height: 6)
                Capsule()
                    .fill(BillBanditMascotPalette.receiptShadow.opacity(0.72))
                    .frame(height: 5)
                Capsule()
                    .fill(BillBanditMascotPalette.receiptShadow.opacity(0.50))
                    .frame(width: 28, height: 5)
                Circle()
                    .fill(BillBanditMascotPalette.blue.opacity(0.88))
                    .frame(width: 24, height: 24)
                    .overlay {
                        Checkmark()
                            .stroke(.white, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                            .padding(6)
                    }
            }
            .padding(12)
        }
    }
}

private struct MascotThoughtBubbles: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack {
                Circle()
                    .fill(BillBanditMascotPalette.receipt)
                    .overlay {
                        Circle()
                            .stroke(BillBanditMascotPalette.blue.opacity(0.34), lineWidth: 2)
                    }
                    .frame(width: width * 0.54, height: width * 0.54)
                    .position(x: width * 0.62, y: height * 0.30)

                Circle()
                    .fill(BillBanditMascotPalette.receipt)
                    .frame(width: width * 0.20, height: width * 0.20)
                    .position(x: width * 0.28, y: height * 0.58)

                Circle()
                    .fill(BillBanditMascotPalette.receipt)
                    .frame(width: width * 0.12, height: width * 0.12)
                    .position(x: width * 0.10, y: height * 0.76)

                EqualSign()
                    .stroke(BillBanditMascotPalette.blue, style: StrokeStyle(lineWidth: width * 0.06, lineCap: .round))
                    .frame(width: width * 0.22, height: height * 0.16)
                    .position(x: width * 0.62, y: height * 0.30)
            }
        }
    }
}

private struct MascotStampMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(BillBanditMascotPalette.blue)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(BillBanditMascotPalette.blueDark, lineWidth: 3)
                }

            VStack(spacing: 6) {
                Checkmark()
                    .stroke(.white, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                    .frame(width: 44, height: 30)
                Capsule()
                    .fill(.white.opacity(0.88))
                    .frame(width: 68, height: 5)
                Capsule()
                    .fill(.white.opacity(0.62))
                    .frame(width: 44, height: 4)
            }
        }
        .shadow(color: BillBanditMascotPalette.blueDark.opacity(0.24), radius: 10, x: 0, y: 6)
    }
}

private struct ReceiptShape: Shape {
    let teeth: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let toothWidth = rect.width / CGFloat(max(teeth, 1))
        let toothDepth = rect.height * 0.10

        path.move(to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.08, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + rect.width * 0.08),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - toothDepth))

        for index in stride(from: teeth, through: 0, by: -1) {
            let x = rect.minX + CGFloat(index) * toothWidth
            let y = index.isMultiple(of: 2) ? rect.maxY : rect.maxY - toothDepth
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + rect.width * 0.08))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}

private struct MaskStripe: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.06, y: rect.midY))
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.10),
            control: CGPoint(x: rect.width * 0.26, y: rect.minY - rect.height * 0.08)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - rect.width * 0.06, y: rect.midY),
            control: CGPoint(x: rect.width * 0.74, y: rect.minY - rect.height * 0.08)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.08),
            control: CGPoint(x: rect.width * 0.74, y: rect.maxY + rect.height * 0.14)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.06, y: rect.midY),
            control: CGPoint(x: rect.width * 0.26, y: rect.maxY + rect.height * 0.14)
        )
        path.closeSubpath()
        return path
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY), control: CGPoint(x: rect.midX, y: rect.maxY * 0.86))
        path.closeSubpath()
        return path
    }
}

private struct RoundedTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.22), control: CGPoint(x: rect.minX, y: rect.maxY * 0.62))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.22), control: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.18))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY * 0.62))
        path.closeSubpath()
        return path
    }
}

private struct Checkmark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.42, y: rect.maxY - rect.height * 0.22))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.14, y: rect.minY + rect.height * 0.22))
        return path
    }
}

private struct Wink: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.midY), control: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

private struct MascotSpark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

private struct EqualSign: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.28))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.28))
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY - rect.height * 0.28))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - rect.height * 0.28))
        return path
    }
}

#Preview("BillBandit Mascots") {
    ScrollView(.horizontal) {
        HStack(spacing: 18) {
            MascotWelcome()
            MascotPeek()
            MascotThinking()
            MascotFinal()
            MascotStamp()
        }
        .padding(24)
    }
    .background(PaisaTheme.pageGradient)
}
