import AppKit
import Combine

@MainActor
final class DesktopClockRenderer {
    private let panel: NSPanel
    private let settings: ClockSettings
    private let surface = ClockTextSurface()
    private let formatter = DateFormatter()
    private var timer: Timer?
    private var settingsSubscription: AnyCancellable?
    private var screenSubscription: AnyCancellable?

    init(panel: NSPanel, settings: ClockSettings) {
        self.panel = panel
        self.settings = settings
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = .autoupdatingCurrent
        panel.contentView = surface
        settingsSubscription = settings.objectWillChange.sink { [weak self] _ in
            // ObservableObject 在赋值前发通知，推迟到本轮赋值完成后再读取配置。
            DispatchQueue.main.async { self?.refresh() }
        }
        screenSubscription = NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in self?.refresh() }
        setVisible(true)
    }

    func setVisible(_ visible: Bool) {
        timer?.invalidate()
        timer = nil
        guard visible else { return }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        timer?.tolerance = 0.1
    }

    private func refresh() {
        let format = settings.format == .custom
            ? ClockDateFormat.normalize(settings.customFormat)
            : settings.format.dateFormat
        if formatter.dateFormat != format { formatter.dateFormat = format }
        let text = formatter.string(from: .now)
        surface.content = ClockText(
            text: text,
            font: ClockTypography.font(name: settings.fontName, size: settings.fontSize, weight: settings.fontWeight),
            color: settings.colorMode,
            opacity: settings.opacity
        ).attributedText
        surface.requiresInversion = settings.colorMode == .adaptive
        surface.textOpacity = settings.opacity
        surface.setAccessibilityLabel(text)
        // 主显示器不随键盘焦点变化，避免打开其他屏幕上的窗口时带走桌面时钟。
        guard let screen = NSScreen.screens.first else { return }
        let frame = Self.frame(size: surface.intrinsicContentSize, screen: screen.frame, position: settings.position)
        // 窗口只覆盖文字矩形，避免为整屏透明区域分配合成表面。
        if panel.frame != frame { panel.setFrame(frame, display: false) }
        surface.layoutSubtreeIfNeeded()
    }

    static func frame(size: NSSize, screen: NSRect, position: ClockPosition) -> NSRect {
        let x: CGFloat
        let y: CGFloat
        switch position {
        case .topLeft, .bottomLeft: x = screen.minX + 48
        case .topRight, .bottomRight: x = screen.maxX - size.width - 48
        case .center: x = screen.midX - size.width / 2
        }
        switch position {
        case .topLeft, .topRight: y = screen.maxY - size.height - 48
        case .bottomLeft, .bottomRight: y = screen.minY + 48
        case .center: y = screen.midY - size.height / 2
        }
        return NSRect(origin: NSPoint(x: x, y: y), size: size)
    }
}

enum ClockDateFormat {
    static func normalize(_ value: String) -> String {
        var tokens: [(text: String, quoted: Bool)] = []
        var quoted = false
        var index = value.startIndex
        while index < value.endIndex {
            let character = value[index]
            if character == "'" {
                tokens.append(("'", true))
                quoted.toggle()
                index = value.index(after: index)
                continue
            }
            let start = index
            repeat {
                index = value.index(after: index)
            } while index < value.endIndex && value[index] == character
            tokens.append((String(value[start..<index]), quoted))
        }
        // 只转换引号外的单字符简写，保留原生格式字段与引号中的字面文本。
        guard tokens.contains(where: { !$0.quoted && ($0.text == "Y" || $0.text == "i") }) else {
            return value
        }
        let replacements = ["Y": "yyyy", "m": "MM", "d": "dd", "H": "HH", "i": "mm", "s": "ss"]
        return tokens.map { $0.quoted ? $0.text : replacements[$0.text] ?? $0.text }.joined()
    }
}
