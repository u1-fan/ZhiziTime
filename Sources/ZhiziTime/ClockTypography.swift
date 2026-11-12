import AppKit
import CoreText
import SwiftUI
import UniformTypeIdentifiers

enum ClockWeight: String, CaseIterable, Identifiable {
    case light
    case regular
    case bold

    var id: String { rawValue }
    var title: String {
        switch self {
        case .light: return "细体"
        case .regular: return "正常"
        case .bold: return "粗体"
        }
    }
    var nsWeight: NSFont.Weight {
        switch self {
        case .light: return .light
        case .regular: return .regular
        case .bold: return .bold
        }
    }
    var swiftUIWeight: Font.Weight {
        switch self {
        case .light: return .light
        case .regular: return .regular
        case .bold: return .bold
        }
    }
}

@MainActor
enum ClockTypography {
    static var fontDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ZhiziTime/Fonts", isDirectory: true)
    }

    static func restoreImportedFonts() {
        let files = (try? FileManager.default.contentsOfDirectory(at: fontDirectory, includingPropertiesForKeys: nil)) ?? []
        for file in files where ["ttf", "otf"].contains(file.pathExtension.lowercased()) {
            CTFontManagerRegisterFontsForURL(file as CFURL, .process, nil)
        }
    }

    static func importFont(from url: URL, directory: URL = fontDirectory) throws -> String {
        guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
              let descriptor = descriptors.first,
              let family = CTFontDescriptorCopyAttribute(descriptor, kCTFontFamilyNameAttribute) as? String else {
            throw FontImportError.invalidFont
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let target = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension(url.pathExtension)
        try FileManager.default.copyItem(at: url, to: target)
        var error: Unmanaged<CFError>?
        if !CTFontManagerRegisterFontsForURL(target as CFURL, .process, &error) {
            let registrationError = error?.takeRetainedValue()
            // 已加载的字体仍可保存到应用目录，确保下次启动可以恢复。
            if registrationError.map({ CFErrorGetCode($0) }) != CTFontManagerError.alreadyRegistered.rawValue {
                try? FileManager.default.removeItem(at: target)
                throw registrationError.map { $0 as Error } ?? FontImportError.invalidFont
            }
        }
        return family
    }

    static func font(name: String, size: Double, weight: ClockWeight) -> NSFont {
        guard name != "系统等宽" else {
            return .monospacedSystemFont(ofSize: size, weight: weight.nsWeight)
        }
        let managerWeight: Int
        switch weight {
        case .light: managerWeight = 2
        case .regular: managerWeight = 5
        case .bold: managerWeight = 9
        }
        // 兼容已保存的 PostScript 名称，按字体族匹配才能应用用户选择的字重。
        let family = NSFont(name: name, size: size)?.familyName ?? name
        return NSFontManager.shared.font(
            withFamily: family,
            traits: [],
            weight: managerWeight,
            size: size
        ) ?? NSFont(name: name, size: size) ?? .systemFont(ofSize: size)
    }
}

enum FontImportError: LocalizedError {
    case invalidFont

    var errorDescription: String? {
        "无法读取这个字体，请选择有效的 .ttf 或 .otf 文件。"
    }
}

struct ClockText: NSViewRepresentable {
    let text: String
    let font: NSFont
    let color: ClockColor
    let opacity: Double
    var invertsDesktop = true

    func makeNSView(context: Context) -> ClockTextSurface {
        ClockTextSurface()
    }

    var attributedText: NSAttributedString {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .kern: 2,
            .foregroundColor: NSColor(color.color).withAlphaComponent(color == .adaptive && invertsDesktop ? 1 : opacity)
        ]
        return NSAttributedString(string: text, attributes: attributes)
    }

    func updateNSView(_ nsView: ClockTextSurface, context: Context) {
        nsView.content = attributedText
        nsView.requiresInversion = color == .adaptive && invertsDesktop
        nsView.textOpacity = opacity
        nsView.setAccessibilityLabel(text)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: ClockTextSurface, context: Context) -> CGSize? {
        nsView.intrinsicContentSize
    }
}

final class ClockTextSurface: NSView {
    private var inversionView: NativeInversionView?
    private var maskNeedsUpdate = true
    var requiresInversion = false {
        didSet {
            guard requiresInversion != oldValue else { return }
            if requiresInversion && inversionView == nil {
                let effect = NativeInversionView(frame: bounds)
                effect.isHidden = true
                addSubview(effect)
                inversionView = effect
            }
            inversionView?.isHidden = !requiresInversion
            maskNeedsUpdate = true
            needsLayout = true
            needsDisplay = true
        }
    }
    var textOpacity = 1.0 {
        didSet { inversionView?.alphaValue = textOpacity }
    }
    var content = NSAttributedString() {
        didSet {
            guard !content.isEqual(to: oldValue) else { return }
            invalidateIntrinsicContentSize()
            maskNeedsUpdate = true
            needsLayout = true
            needsDisplay = true
        }
    }

    override var isFlipped: Bool { true }
    override var intrinsicContentSize: NSSize {
        let size = content.size()
        return NSSize(width: ceil(size.width) + 8, height: ceil(size.height) + 8)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
    }

    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        guard requiresInversion, let inversionView else { return }
        if inversionView.frame != bounds {
            inversionView.frame = bounds
            maskNeedsUpdate = true
        }
        if maskNeedsUpdate {
            inversionView.maskImage = NativeInversion.glyphMask(
                content, size: bounds.size, scale: window?.backingScaleFactor ?? 2
            )
            inversionView.isHidden = inversionView.maskImage == nil
            maskNeedsUpdate = false
        }
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        maskNeedsUpdate = true
        needsLayout = true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        maskNeedsUpdate = true
        needsLayout = true
    }

    override func draw(_ dirtyRect: NSRect) {
        if !requiresInversion {
            content.draw(at: NSPoint(x: 4, y: 4))
        }
    }
}
