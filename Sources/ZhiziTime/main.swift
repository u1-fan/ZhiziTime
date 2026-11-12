import AppKit
import SwiftUI
import Combine

@main
struct ZhiziTimeApp {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        // 菜单栏应用的窗口由代理管理，避免额外生成空白的 SwiftUI 设置窗口。
        withExtendedLifetime(delegate) {
            application.run()
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
    private var desktopClock: DesktopClockRenderer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        createMainMenu()
        createPanel()
        createStatusItem()
    }

    private func createMainMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: "智子时间")
        let settingsItem = NSMenuItem(title: "设置…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())
        let quitItem = NSMenuItem(title: "退出智子时间", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        appMenu.addItem(quitItem)
        appItem.submenu = appMenu
        menu.addItem(appItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "编辑")
        for (title, action, key) in [
            ("撤销", Selector(("undo:")), "z"),
            ("重做", Selector(("redo:")), "Z"),
            ("剪切", #selector(NSText.cut(_:)), "x"),
            ("复制", #selector(NSText.copy(_:)), "c"),
            ("粘贴", #selector(NSText.paste(_:)), "v"),
            ("全选", #selector(NSText.selectAll(_:)), "a")
        ] {
            editMenu.addItem(NSMenuItem(title: title, action: action, keyEquivalent: key))
        }
        editItem.submenu = editMenu
        menu.addItem(editItem)
        NSApp.mainMenu = menu
    }

    private func createPanel() {
        panel = ZhiziPanel(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
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
        desktopClock = DesktopClockRenderer(panel: panel, settings: settings)
        panel.orderFrontRegardless()
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
                contentRect: NSRect(x: 0, y: 0, width: 1040, height: 760),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "智子时间设置"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            // 扩大无控件背景区域的拖动范围，避免只能抓住最顶部标题栏移动窗口。
            window.isMovableByWindowBackground = true
            window.backgroundColor = NSColor(red: 0.025, green: 0.045, blue: 0.065, alpha: 1)
            window.minSize = NSSize(width: 980, height: 720)
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
        desktopClock?.setVisible(isVisible)
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

struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        WindowDragView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class WindowDragView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
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
    @Published var appearance: ConsoleAppearance { didSet { save() } }
    @Published var fontWeight: ClockWeight { didSet { save() } }

    @Published private(set) var fonts: [String]

    init() {
        ClockTypography.restoreImportedFonts()
        fonts = ["系统等宽"] + NSFontManager.shared.availableFontFamilies.sorted()
        let defaults = UserDefaults.standard
        let storedFontName = defaults.string(forKey: "fontName") ?? "系统等宽"
        fontName = NSFont(name: storedFontName, size: 42)?.familyName ?? storedFontName
        fontSize = defaults.object(forKey: "fontSize") as? Double ?? 42
        opacity = defaults.object(forKey: "opacity") as? Double ?? 0.48
        position = ClockPosition(rawValue: defaults.string(forKey: "position") ?? "center") ?? .center
        format = ClockFormat(rawValue: defaults.string(forKey: "format") ?? "zh") ?? .chinese
        customFormat = defaults.string(forKey: "customFormat") ?? "yyyy-MM-dd HH:mm:ss"
        colorMode = ClockColor(rawValue: defaults.string(forKey: "colorMode") ?? "adaptive") ?? .adaptive
        appearance = ConsoleAppearance(rawValue: defaults.string(forKey: "appearance") ?? "night") ?? .night
        fontWeight = ClockWeight(rawValue: defaults.string(forKey: "fontWeight") ?? "light") ?? .light
    }

    func reset() {
        fontName = "系统等宽"
        fontSize = 42
        opacity = 0.48
        position = .center
        format = .chinese
        customFormat = "yyyy-MM-dd HH:mm:ss"
        colorMode = .adaptive
        appearance = .night
        fontWeight = .light
    }

    func importFont(from url: URL) throws {
        fontName = try ClockTypography.importFont(from: url)
        fonts = ["系统等宽"] + Array(Set([fontName] + NSFontManager.shared.availableFontFamilies)).sorted()
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
        defaults.set(appearance.rawValue, forKey: "appearance")
        defaults.set(fontWeight.rawValue, forKey: "fontWeight")
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
        case .adaptive: return "背景反相"
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
        case .chinese: return "年-月-日 时:分:秒"
        case .iso: return "yyyy-MM-dd HH:mm:ss"
        case .slash: return "yyyy/MM/dd HH:mm:ss"
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
    var isPreview = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Group {
                if isPreview {
                    clockText(context.date)
                        .blendMode(settings.colorMode == .adaptive ? .difference : .normal)
                } else {
                    // 桌面文字保留原生图层，避免 SwiftUI 混合效果将背景合成栅格化。
                    clockText(context.date)
                }
            }
                .fixedSize()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: settings.position.alignment)
                .padding(48)
                .allowsHitTesting(false)
        }
        .background(Color.clear)
        .ignoresSafeArea()
    }

    private func clockText(_ date: Date) -> ClockText {
        ClockText(
            text: formattedDate(date),
            font: ClockTypography.font(name: settings.fontName, size: settings.fontSize, weight: settings.fontWeight),
            color: settings.colorMode,
            opacity: settings.opacity,
            invertsDesktop: !isPreview
        )
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = settings.format == .custom
            ? ClockDateFormat.normalize(settings.customFormat)
            : settings.format.dateFormat
        return formatter.string(from: date)
    }

}
