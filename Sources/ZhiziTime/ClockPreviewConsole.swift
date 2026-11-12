import AppKit
import SwiftUI

struct ClockPreviewConsole: View {
    @ObservedObject var settings: ClockSettings
    @State private var lightBackground = false

    private var screenSize: CGSize {
        NSScreen.screens.first?.frame.size ?? CGSize(width: 1440, height: 900)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 7) {
                    Circle().fill(ConsoleStyle.cyan).frame(width: 5, height: 5)
                    Text("时序观测")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Text("TEMPORAL CORE")
                        .font(ConsoleStyle.telemetry(9))
                        .tracking(1.5)
                        .foregroundStyle(ConsoleStyle.muted)
                }
                temporalCore
                HStack {
                    Text("桌面投影")
                        .font(.system(size: 10, weight: .medium))
                    Spacer()
                    Text("01 / LIVE VIEW")
                        .font(ConsoleStyle.telemetry(8))
                        .foregroundStyle(ConsoleStyle.cyan)
                }
                preview
                HStack {
                    Label("预览背景", systemImage: "circle.lefthalf.filled")
                        .font(.system(size: 11))
                        .foregroundStyle(ConsoleStyle.muted)
                    Spacer()
                    Picker("预览背景", selection: $lightBackground) {
                        Text("深色").tag(false)
                        Text("浅色").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 112)
                }
                .padding(.top, -4)
                telemetry
                missionNote
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .frame(maxHeight: .infinity)
        .background {
            HUDCutout()
                .fill(ConsoleStyle.surface.opacity(0.6))
                .overlay { HUDFrame() }
        }
        .clipShape(HUDCutout())
    }

    private var temporalCore: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            ZStack {
                RadialGradient(colors: [ConsoleStyle.cyan.opacity(0.12), .clear],
                               center: .center, startRadius: 15, endRadius: 125)
                OrbitalReticle()
                Circle()
                    .fill(ConsoleStyle.amber)
                    .frame(width: 5, height: 5)
                    .offset(y: -99)
                    .rotationEffect(.degrees(Double(Calendar.current.component(.second, from: context.date)) * 6))
                VStack(spacing: 10) {
                    Text("本 地 时 间")
                        .font(.system(size: 9))
                        .foregroundStyle(ConsoleStyle.muted)
                    Text(context.date, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).second(.twoDigits))
                        .font(.system(size: 31, weight: .ultraLight, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(ConsoleStyle.cyan)
                        .shadow(color: ConsoleStyle.cyan.opacity(0.4), radius: 10)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(ConsoleStyle.background.opacity(0.92))
                    Text(context.date, format: .dateTime.year().month(.twoDigits).day(.twoDigits))
                        .font(ConsoleStyle.telemetry(10))
                        .foregroundStyle(ConsoleStyle.muted)
                }
            }
            .frame(height: 230)
            .overlay(alignment: .topLeading) {
                Text("T+LOCAL")
                    .font(ConsoleStyle.telemetry(8))
                    .foregroundStyle(ConsoleStyle.amber)
            }
            .overlay(alignment: .bottomTrailing) {
                Text("1 Hz / 系统时钟")
                    .font(ConsoleStyle.telemetry(8))
                    .foregroundStyle(ConsoleStyle.muted)
            }
        }
    }

    private var preview: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(0..<3) { _ in
                    Circle().fill(ConsoleStyle.muted.opacity(0.4)).frame(width: 4, height: 4)
                }
                Spacer()
                Text("DESKTOP / 01").font(ConsoleStyle.telemetry(7))
                    .tracking(1)
                    .foregroundStyle(ConsoleStyle.muted)
            }
            .padding(10)
            .background(ConsoleStyle.background)

            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    desktopBackground
                    // 按真实屏幕比例缩放，预览中的字号与边距才和桌面一致。
                    ZhiziClockView(settings: settings, isPreview: true)
                        .frame(width: screenSize.width, height: screenSize.height)
                        .scaleEffect(geometry.size.width / screenSize.width, anchor: .topLeading)
                        .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
                }
                .compositingGroup()
                .clipped()
            }
            .frame(height: 280 * screenSize.height / screenSize.width)
            .accessibilityLabel("桌面时间实时预览，当前位置\(settings.position.title)")

            HStack {
                Text("\(Int(screenSize.width)) × \(Int(screenSize.height))")
                Spacer()
                Text("按屏幕比例预览")
            }
            .font(ConsoleStyle.telemetry(8))
            .foregroundStyle(ConsoleStyle.muted)
            .padding(10)
            .background(ConsoleStyle.background)
        }
        .clipShape(HUDCutout(cut: 10))
        .overlay {
            HUDCutout(cut: 10)
                .stroke(ConsoleStyle.cyan.opacity(0.4), lineWidth: 1)
        }
    }

    private var desktopBackground: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: lightBackground
                        ? [Color(red: 0.78, green: 0.85, blue: 0.87), Color(red: 0.94, green: 0.93, blue: 0.86)]
                        : [Color(red: 0.025, green: 0.08, blue: 0.12), Color(red: 0.08, green: 0.20, blue: 0.23)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Circle()
                    .fill(
                        RadialGradient(
                            colors: lightBackground
                                ? [.white.opacity(0.7), .gray.opacity(0.1)]
                                : [ConsoleStyle.cyan.opacity(0.12), .black.opacity(0.6)],
                            center: .topLeading, startRadius: 0, endRadius: 140
                        )
                    )
                    .overlay { Circle().strokeBorder(ConsoleStyle.cyan.opacity(0.24), lineWidth: 0.5) }
                    .frame(width: geometry.size.width * 0.7, height: geometry.size.width * 0.7)
                    .position(x: geometry.size.width * 0.8, y: geometry.size.height * 1.08)
                Ellipse()
                    .stroke(ConsoleStyle.cyan.opacity(0.18), lineWidth: 0.5)
                    .frame(width: geometry.size.width * 1.2, height: geometry.size.height * 0.5)
                    .rotationEffect(.degrees(-28))
                    .position(x: geometry.size.width * 0.72, y: geometry.size.height * 0.9)
            }
        }
        .accessibilityHidden(true)
    }

    private var telemetry: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("当前配置 / READOUT")
                .font(ConsoleStyle.telemetry(9))
                .tracking(1)
                .foregroundStyle(ConsoleStyle.muted)
            readout("定位锚点", value: settings.position.title)
            readout("字体颜色", value: settings.colorMode.title)
            readout("时区", value: TimeZone.current.identifier)
        }
    }

    private var missionNote: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "waveform.path")
                Text("时间，始终在场。")
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(ConsoleStyle.cyan)
            Text("悬浮于桌面之上，在每个空间与你同步。")
                .font(.system(size: 10))
                .foregroundStyle(ConsoleStyle.muted)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 3) {
                ForEach(0..<40) { index in
                    Rectangle()
                        .fill(ConsoleStyle.cyan.opacity(index.isMultiple(of: 5) ? 0.6 : 0.16))
                        .frame(height: index.isMultiple(of: 5) ? 9 : 4)
                }
            }
            .padding(.top, 8)
            .accessibilityHidden(true)
        }
        .padding(.top, 10)
    }

    private func readout(_ label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(ConsoleStyle.muted)
            Spacer()
            Text(value).lineLimit(1).textSelection(.enabled)
        }
        .font(.system(size: 11))
    }
}
