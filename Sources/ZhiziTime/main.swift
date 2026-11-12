import AppKit
import SwiftUI

@main
struct ZhiziTimeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: ZhiziPanel!
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private let settings = ClockSettings()
    private var isVisible = true

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        createPanel()
        createStatusItem()
    }

    private func createPanel() {
        panel = ZhiziPanel(
            contentRect: NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.contentView = NSHostingView(rootView: ZhiziClockView(settings: settings))
        positionPanel()
        panel.orderFrontRegardless()
    }

    private func positionPanel() {
        guard let screen = NSScreen.main else { return }
        panel.setFrame(screen.frame, display: true)
    }

    private func createStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "clock", accessibilityDescription: "智子时间")
        statusItem.button?.toolTip = "智子时间"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "设置…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "隐藏时间", action: #selector(togglePanel), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))
        menu.items[0].target = self
        menu.items[1].target = self
        menu.items[3].target = self
        statusItem.menu = menu
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let view = ClockSettingsView(settings: settings)
            let hostingView = NSHostingView(rootView: view)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 440, height: 510),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "智子时间设置"
            window.contentView = hostingView
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func togglePanel() {
        isVisible.toggle()
        if isVisible {
            panel.orderFrontRegardless()
        } else {
            panel.orderOut(nil)
        }
        statusItem.menu?.items[1].title = isVisible ? "隐藏时间" : "显示时间"
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

final class ZhiziPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class ClockSettings: ObservableObject {
    @Published var fontName: String { didSet { save() } }
    @Published var fontSize: Double { didSet { save() } }
    @Published var opacity: Double { didSet { save() } }
    @Published var position: ClockPosition { didSet { save() } }
    @Published var format: ClockFormat { didSet { save() } }
    @Published var customFormat: String { didSet { save() } }
    @Published var colorMode: ClockColor { didSet { save() } }

    let fonts = ["系统等宽", "SF Mono", "Menlo", "Helvetica Neue", "Avenir Next", "Courier"]

    init() {
        let defaults = UserDefaults.standard
        fontName = defaults.string(forKey: "fontName") ?? "系统等宽"
        fontSize = defaults.object(forKey: "fontSize") as? Double ?? 42
        opacity = defaults.object(forKey: "opacity") as? Double ?? 0.48
        position = ClockPosition(rawValue: defaults.string(forKey: "position") ?? "center") ?? .center
        format = ClockFormat(rawValue: defaults.string(forKey: "format") ?? "zh") ?? .chinese
        customFormat = defaults.string(forKey: "customFormat") ?? "yyyy-MM-dd HH:mm:ss"
        colorMode = ClockColor(rawValue: defaults.string(forKey: "colorMode") ?? "adaptive") ?? .adaptive
    }

    func reset() {
        fontName = "系统等宽"
        fontSize = 42
        opacity = 0.48
        position = .center
        format = .chinese
        customFormat = "yyyy-MM-dd HH:mm:ss"
        colorMode = .adaptive
    }

    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(fontName, forKey: "fontName")
        defaults.set(fontSize, forKey: "fontSize")
        defaults.set(opacity, forKey: "opacity")
        defaults.set(position.rawValue, forKey: "position")
        defaults.set(format.rawValue, forKey: "format")
        defaults.set(customFormat, forKey: "customFormat")
        defaults.set(colorMode.rawValue, forKey: "colorMode")
    }
}

enum ClockColor: String, CaseIterable, Identifiable {
    case adaptive = "adaptive"
    case white = "white"
    case black = "black"
    case orange = "orange"
    case red = "red"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .adaptive: return "自动适配背景"
        case .white: return "白色"
        case .black: return "黑色"
        case .orange: return "橙色"
        case .red: return "红色"
        }
    }

    var color: Color {
        switch self {
        case .adaptive, .white: return .white
        case .black: return .black
        case .orange: return .orange
        case .red: return .red
        }
    }
}

enum ClockPosition: String, CaseIterable, Identifiable {
    case topLeft = "topLeft"
    case topRight = "topRight"
    case center = "center"
    case bottomLeft = "bottomLeft"
    case bottomRight = "bottomRight"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .topLeft: return "左上"
        case .topRight: return "右上"
        case .center: return "居中"
        case .bottomLeft: return "左下"
        case .bottomRight: return "右下"
        }
    }

    var alignment: Alignment {
        switch self {
        case .topLeft: return .topLeading
        case .topRight: return .topTrailing
        case .center: return .center
        case .bottomLeft: return .bottomLeading
        case .bottomRight: return .bottomTrailing
        }
    }
}

enum ClockFormat: String, CaseIterable, Identifiable {
    case chinese = "zh"
    case iso = "iso"
    case slash = "slash"
    case custom = "custom"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chinese: return "2026年11月12日 01:20:45"
        case .iso: return "2026-11-12 01:20:45"
        case .slash: return "2026/11/12 01:20:45"
        case .custom: return "自定义格式"
        }
    }

    var dateFormat: String {
        switch self {
        case .chinese: return "yyyy年MM月dd日 HH:mm:ss"
        case .iso: return "yyyy-MM-dd HH:mm:ss"
        case .slash: return "yyyy/MM/dd HH:mm:ss"
        case .custom: return ""
        }
    }
}

struct ZhiziClockView: View {
    @ObservedObject var settings: ClockSettings

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(formattedDate(context.date))
                .font(selectedFont)
                .monospacedDigit()
                .foregroundStyle(settings.colorMode.color.opacity(settings.opacity))
                .blendMode(settings.colorMode == .adaptive ? .difference : .normal)
                .tracking(2)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: settings.position.alignment)
                .padding(48)
                .allowsHitTesting(false)
        }
        .background(Color.clear)
        .ignoresSafeArea()
    }

    private var selectedFont: Font {
        if settings.fontName == "系统等宽" {
            return .system(size: settings.fontSize, weight: .light, design: .monospaced)
        }
        return .custom(settings.fontName, size: settings.fontSize)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = settings.format == .custom
            ? normalizedCustomFormat(settings.customFormat)
            : settings.format.dateFormat
        return formatter.string(from: date)
    }

    private func normalizedCustomFormat(_ value: String) -> String {
        guard value.contains("Y") || value.contains("i") else {
            return value
        }
        return value
            .replacingOccurrences(of: "Y", with: "yyyy")
            .replacingOccurrences(of: "m", with: "MM")
            .replacingOccurrences(of: "d", with: "dd")
            .replacingOccurrences(of: "H", with: "HH")
            .replacingOccurrences(of: "i", with: "mm")
            .replacingOccurrences(of: "s", with: "ss")
    }
}

struct ClockSettingsView: View {
    @ObservedObject var settings: ClockSettings

    var body: some View {
        Form {
            Section("显示样式") {
                Picker("字体", selection: $settings.fontName) {
                    ForEach(settings.fonts, id: \.self) { font in
                        Text(font).tag(font)
                    }
                }

                Picker("字体颜色", selection: $settings.colorMode) {
                    ForEach(ClockColor.allCases) { color in
                        Text(color.title).tag(color)
                    }
                }

                HStack {
                    Text("大小")
                    Slider(value: $settings.fontSize, in: 16...120, step: 1)
                    Text("\(Int(settings.fontSize))")
                        .monospacedDigit()
                        .frame(width: 36, alignment: .trailing)
                }

                HStack {
                    Text("亮度")
                    Slider(value: $settings.opacity, in: 0.05...1.0, step: 0.01)
                    Text("\(Int(settings.opacity * 100))%")
                        .monospacedDigit()
                        .frame(width: 42, alignment: .trailing)
                }

                Picker("位置", selection: $settings.position) {
                    ForEach(ClockPosition.allCases) { position in
                        Text(position.title).tag(position)
                    }
                }
            }

            Section("时间格式") {
                Picker("格式", selection: $settings.format) {
                    ForEach(ClockFormat.allCases) { format in
                        Text(format.title).tag(format)
                    }
                }

                if settings.format == .custom {
                    TextField("例如 Y-m-d H:i:s", text: $settings.customFormat)
                        .textFieldStyle(.roundedBorder)
                    Text("支持：Y 年、m 月、d 日、H 时、i 分、s 秒；也可直接使用 yyyy-MM-dd。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Spacer()
                Button("恢复默认") {
                    settings.reset()
                }
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 8)
        .frame(width: 440, height: 510)
    }
}
