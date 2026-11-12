import AppKit
import SwiftUI

enum ConsoleAppearance: String, CaseIterable, Identifiable {
    case day
    case night

    var id: String { rawValue }
    var title: String { self == .day ? "日间" : "夜间" }
    var symbol: String { self == .day ? "sun.max" : "moon.stars" }
    var colorScheme: ColorScheme { self == .day ? .light : .dark }
}

enum ConsoleStyle {
    static let background = adaptive(day: (0.88, 0.93, 0.93), night: (0.012, 0.025, 0.043))
    static let surface = adaptive(day: (0.96, 0.99, 0.98), night: (0.025, 0.065, 0.085))
    static let cyan = adaptive(day: (0.0, 0.36, 0.38), night: (0.18, 0.98, 0.88))
    static let amber = adaptive(day: (0.55, 0.29, 0.06), night: (1.0, 0.69, 0.29))
    static let text = adaptive(day: (0.08, 0.18, 0.21), night: (0.88, 0.94, 0.96))
    static let muted = adaptive(day: (0.32, 0.43, 0.46), night: (0.53, 0.65, 0.70))
    static let line = cyan.opacity(0.25)

    static func telemetry(_ size: CGFloat = 10) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }

    private static func adaptive(
        day: (Double, Double, Double), night: (Double, Double, Double)
    ) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let rgb = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? night : day
            return NSColor(srgbRed: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        })
    }
}

struct ConsolePanel<Content: View>: View {
    let index: String
    let title: String
    let code: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                Text(index)
                    .font(ConsoleStyle.telemetry(12))
                    .foregroundStyle(ConsoleStyle.background)
                    .frame(width: 29, height: 24)
                    .background(ConsoleStyle.cyan, in: HUDCutout(cut: 5))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(code)
                    .font(ConsoleStyle.telemetry(9))
                    .tracking(1.5)
                    .foregroundStyle(ConsoleStyle.cyan.opacity(0.65))
            }
            Rectangle()
                .fill(LinearGradient(colors: [ConsoleStyle.cyan.opacity(0.5), ConsoleStyle.line, .clear], startPoint: .leading, endPoint: .trailing))
                .frame(height: 1)
                .padding(.top, -8)
            content
        }
        .padding(14)
        .background(ConsoleStyle.surface.opacity(0.8))
        .clipShape(HUDCutout())
        .overlay { HUDFrame() }
    }
}

struct ConsoleButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
    }
}

struct ConsoleGrid: View {
    var body: some View {
        Canvas { context, size in
            var grid = Path()
            for x in stride(from: 0.0, through: size.width, by: 28) {
                grid.move(to: CGPoint(x: x, y: 0))
                grid.addLine(to: CGPoint(x: x, y: size.height))
            }
            for y in stride(from: 0.0, through: size.height, by: 28) {
                grid.move(to: CGPoint(x: 0, y: y))
                grid.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(grid, with: .color(ConsoleStyle.cyan.opacity(0.07)), lineWidth: 0.5)
            var marks = Path()
            for x in stride(from: 28.0, through: size.width, by: 112) {
                for y in stride(from: 28.0, through: size.height, by: 112) {
                    marks.move(to: CGPoint(x: x - 3, y: y))
                    marks.addLine(to: CGPoint(x: x + 3, y: y))
                    marks.move(to: CGPoint(x: x, y: y - 3))
                    marks.addLine(to: CGPoint(x: x, y: y + 3))
                }
            }
            context.stroke(marks, with: .color(ConsoleStyle.cyan.opacity(0.22)), lineWidth: 0.5)
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

struct HUDCutout: Shape {
    var cut: CGFloat = 16

    func path(in rect: CGRect) -> Path {
        let corner = min(cut, min(rect.width, rect.height) / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + corner, y: rect.minY))
        for point in [
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.maxY - corner),
            CGPoint(x: rect.maxX - corner, y: rect.maxY),
            CGPoint(x: rect.minX, y: rect.maxY),
            CGPoint(x: rect.minX, y: rect.minY + corner)
        ] {
            path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}

struct HUDFrame: View {
    var body: some View {
        GeometryReader { geometry in
            HUDCutout().stroke(ConsoleStyle.line, lineWidth: 1)
            Path { path in
                path.move(to: CGPoint(x: 0, y: 44))
                path.addLine(to: CGPoint(x: 0, y: 16))
                path.addLine(to: CGPoint(x: 16, y: 0))
                path.addLine(to: CGPoint(x: 66, y: 0))
                path.move(to: CGPoint(x: geometry.size.width - 66, y: geometry.size.height))
                for point in [
                    CGPoint(x: geometry.size.width - 16, y: geometry.size.height),
                    CGPoint(x: geometry.size.width, y: geometry.size.height - 16),
                    CGPoint(x: geometry.size.width, y: geometry.size.height - 44)
                ] {
                    path.addLine(to: point)
                }
            }
            .stroke(ConsoleStyle.cyan.opacity(0.8), lineWidth: 2)
            .shadow(color: ConsoleStyle.cyan.opacity(0.35), radius: 5)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct OrbitalReticle: View {
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 12
            for index in 0..<120 {
                let angle = Double(index) * .pi / 60
                let major = index.isMultiple(of: 10)
                let inner = radius - (major ? 10.0 : 3.0)
                var tick = Path()
                tick.move(to: CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner))
                tick.addLine(to: CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius))
                context.stroke(tick, with: .color(ConsoleStyle.cyan.opacity(major ? 0.8 : 0.35)), lineWidth: major ? 1.5 : 0.6)
            }
            for (inset, opacity) in [(18.0, 0.25), (29.0, 0.12), (52.0, 0.12)] {
                let orbit = CGRect(x: center.x - radius + inset, y: center.y - radius + inset,
                                   width: (radius - inset) * 2, height: (radius - inset) * 2)
                context.stroke(Path(ellipseIn: orbit), with: .color(ConsoleStyle.cyan.opacity(opacity)), lineWidth: 0.8)
            }
            for start in [195.0, 15.0] {
                var arc = Path()
                arc.addArc(center: center, radius: radius - 18, startAngle: .degrees(start), endAngle: .degrees(start + 65), clockwise: false)
                context.stroke(arc, with: .color(ConsoleStyle.cyan.opacity(0.85)), style: StrokeStyle(lineWidth: 3, lineCap: .square))
            }
            var cross = Path()
            cross.move(to: CGPoint(x: center.x - radius - 8, y: center.y))
            cross.addLine(to: CGPoint(x: center.x + radius + 8, y: center.y))
            cross.move(to: CGPoint(x: center.x, y: center.y - radius - 8))
            cross.addLine(to: CGPoint(x: center.x, y: center.y + radius + 8))
            context.stroke(cross, with: .color(ConsoleStyle.cyan.opacity(0.16)),
                           style: StrokeStyle(lineWidth: 0.5, dash: [3, 5]))
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

struct ObservatoryBackdrop: View {
    var body: some View {
        GeometryReader { geometry in
            ConsoleGrid()
            OrbitalReticle()
                .frame(width: 720, height: 720)
                .opacity(0.13)
                .position(x: geometry.size.width * 0.84, y: geometry.size.height * 0.4)
            Canvas { context, size in
                var horizon = Path()
                let vanishingPoint = CGPoint(x: size.width * 0.65, y: size.height * 0.45)
                for x in stride(from: -size.width, through: size.width * 2, by: 100) {
                    horizon.move(to: vanishingPoint)
                    horizon.addLine(to: CGPoint(x: x, y: size.height))
                }
                for fraction in [0.56, 0.63, 0.73, 0.86, 0.99] {
                    let y = size.height * fraction
                    horizon.move(to: CGPoint(x: 0, y: y))
                    horizon.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(horizon, with: .color(ConsoleStyle.cyan.opacity(0.09)), lineWidth: 0.6)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct OrbitalMark: View {
    var body: some View {
        ZStack {
            Circle().stroke(ConsoleStyle.cyan.opacity(0.14), lineWidth: 1)
            Circle().inset(by: 9).stroke(ConsoleStyle.cyan.opacity(0.32), lineWidth: 1)
            Ellipse()
                .stroke(ConsoleStyle.cyan.opacity(0.7), lineWidth: 1)
                .frame(height: 15)
                .rotationEffect(.degrees(-40))
            Circle()
                .fill(ConsoleStyle.cyan)
                .frame(width: 6, height: 6)
                .shadow(color: ConsoleStyle.cyan.opacity(0.5), radius: 6)
        }
        .frame(width: 44, height: 44)
        .accessibilityHidden(true)
    }
}
