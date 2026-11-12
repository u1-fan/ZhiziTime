import AppKit
import CoreText
import Testing
@testable import ZhiziTime

@MainActor
struct ClockRenderingTests {
    @Test
    func compactOverlayKeepsAnchorsOnScreenWithNegativeOrigin() {
        let screen = NSRect(x: -1440, y: 0, width: 1440, height: 900)
        let size = NSSize(width: 300, height: 60)
        let anchors: [(ClockPosition, NSPoint)] = [
            (.topLeft, NSPoint(x: -1392, y: 792)),
            (.topRight, NSPoint(x: -348, y: 792)),
            (.center, NSPoint(x: -870, y: 420)),
            (.bottomLeft, NSPoint(x: -1392, y: 48)),
            (.bottomRight, NSPoint(x: -348, y: 48))
        ]
        for (position, origin) in anchors {
            let frame = DesktopClockRenderer.frame(size: size, screen: screen, position: position)
            #expect(frame.origin == origin)
            #expect(frame.size == size, "悬浮窗口只能占文字区域，不能回退为整屏窗口")
            #expect(screen.contains(frame))
        }
    }

    @Test
    func weightChangesActualRenderedInk() throws {
        for name in ["系统等宽", "Helvetica Neue", "HelveticaNeue"] {
            let ink = try ClockWeight.allCases.map { weight in
                let font = ClockTypography.font(name: name, size: 42, weight: weight)
                let text = ClockText(text: "12:34:56", font: font, color: .black, opacity: 1).attributedText
                return try pixels(text, background: .white).reduce(0) { $0 + 1 - $1 }
            }
            #expect(ink[0] < ink[1], "细体应比正常字重使用更少的墨量：\(name)")
            #expect(ink[1] < ink[2], "粗体应比正常字重使用更多的墨量：\(name)")
        }
    }

    @Test(arguments: [
        ("Y-m-d H:i:s", "2024-12-30 13:05:09"),
        ("yyyy-MM-dd 'is' HH:mm:ss", "2024-12-30 is 13:05:09"),
        ("YYYY-MM-dd", "2025-12-30"),
        ("'Y-m-d' Y-m-d 'H:i:s' H:i:s", "Y-m-d 2024-12-30 H:i:s 13:05:09"),
        ("'it''s' yyyy-MM-dd", "it's 2024-12-30")
    ])
    func customFormatPreservesNativeTokensAndQuotedText(format: String, expected: String) throws {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let date = try #require(formatter.calendar.date(from: DateComponents(
            timeZone: formatter.timeZone, year: 2024, month: 12, day: 30,
            hour: 13, minute: 5, second: 9
        )))
        formatter.dateFormat = ClockDateFormat.normalize(format)
        #expect(formatter.string(from: date) == expected)
    }

    @Test
    func importedFontIsCopiedAndInvalidFileIsRejected() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let font = CTFontCreateWithName("ArialMT" as CFString, 14, nil)
        let source = try #require(CTFontCopyAttribute(font, kCTFontURLAttribute) as? URL)
        let family = try ClockTypography.importFont(from: source, directory: directory)
        #expect(family == "Arial")
        let regular = ClockTypography.font(name: family, size: 20, weight: .regular)
        let bold = ClockTypography.font(name: family, size: 20, weight: .bold)
        #expect(regular.familyName == family)
        #expect(bold.familyName == family)
        #expect(NSFontManager.shared.weight(of: regular) < NSFontManager.shared.weight(of: bold))
        let copies = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        #expect(copies.count == 1)
        #expect(try Data(contentsOf: copies[0]) == Data(contentsOf: source))
        let invalid = directory.appendingPathComponent("invalid.ttf")
        try Data("invalid font".utf8).write(to: invalid)
        #expect(throws: FontImportError.self) {
            try ClockTypography.importFont(from: invalid, directory: directory)
        }
    }

    @Test
    func inversionMaskPreservesTransparentPaddingAtRetinaScale() throws {
        let text = ClockText(
            text: "智子 12:34", font: .monospacedSystemFont(ofSize: 42, weight: .regular),
            color: .adaptive, opacity: 0.1
        ).attributedText
        let surface = ClockTextSurface()
        surface.content = text
        let size = surface.intrinsicContentSize
        var coverage: [Double] = []
        for scale in [CGFloat(1), CGFloat(2)] {
            let mask = try #require(NativeInversion.glyphMask(text, size: size, scale: scale))
            let image = try #require(mask.cgImage(forProposedRect: nil, context: nil, hints: nil))
            let bitmap = NSBitmapImageRep(cgImage: image)
            #expect(bitmap.pixelsWide == Int(size.width * scale))
            #expect(bitmap.pixelsHigh == Int(size.height * scale))
            var alpha = 0.0
            var hasOpaqueGlyph = false
            for y in 0..<bitmap.pixelsHigh {
                for x in 0..<bitmap.pixelsWide {
                    let value = try #require(bitmap.colorAt(x: x, y: y)).alphaComponent
                    alpha += value
                    hasOpaqueGlyph = hasOpaqueGlyph || value > 0.99
                    if x < Int(2 * scale) || y < Int(2 * scale) ||
                        x >= bitmap.pixelsWide - Int(2 * scale) || y >= bitmap.pixelsHigh - Int(2 * scale) {
                        #expect(value == 0, "文字之外必须透明，不能把整个矩形都反相")
                    }
                }
            }
            #expect(hasOpaqueGlyph, "遮罩应保留完整字形透明度，避免把不透明度重复乘两次")
            coverage.append(alpha / Double(scale * scale))
        }
        #expect(abs(coverage[0] - coverage[1]) / coverage[0] < 0.1, "Retina 缩放不应改变字形覆盖面积")
    }

    private func pixels(_ text: NSAttributedString, background: NSColor) throws -> [Double] {
        _ = NSApplication.shared
        let surface = ClockTextSurface()
        surface.content = text
        let size = surface.intrinsicContentSize
        let bitmap = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ))
        let context = try #require(NSGraphicsContext(bitmapImageRep: bitmap))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        background.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        surface.draw(NSRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()
        return (0..<bitmap.pixelsHigh).flatMap { y in
            (0..<bitmap.pixelsWide).map { x in
                Double(bitmap.colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!.redComponent)
            }
        }
    }
}
