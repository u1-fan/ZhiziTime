import AppKit
import QuartzCore

@MainActor
enum NativeInversion {
    static var isAvailable: Bool {
        guard let backdropClass = NSClassFromString("CABackdropLayer") as? CALayer.Type else { return false }
        return backdropClass.instancesRespond(to: NSSelectorFromString("setScale:")) && makeFilter() != nil
    }

    static func makeFilter() -> NSObject? {
        let selector = NSSelectorFromString("filterWithType:")
        guard let filterClass = NSClassFromString("CAFilter") as? NSObject.Type,
              filterClass.responds(to: selector) else { return nil }
        return filterClass.perform(selector, with: "colorInvert")?.takeUnretainedValue() as? NSObject
    }

    static func glyphMask(_ text: NSAttributedString, size: NSSize, scale: CGFloat) -> NSImage? {
        guard size.width > 0, size.height > 0, scale > 0,
              let context = CGContext(
                data: nil, width: Int(ceil(size.width * scale)), height: Int(ceil(size.height * scale)),
                bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        text.draw(at: NSPoint(x: 4, y: 4))
        NSGraphicsContext.restoreGraphicsState()
        guard let image = context.makeImage() else { return nil }
        return NSImage(cgImage: image, size: size)
    }
}

final class NativeInversionView: NSVisualEffectView {
    private let inverseFilter = NativeInversion.makeFilter()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        material = .hudWindow
        blendingMode = .behindWindow
        state = .active
        wantsLayer = true
        // 由 WindowServer 保留实时背景合成，避免在应用内把图层栅格化。
        layerUsesCoreImageFilters = false
        setAccessibilityElement(false)
    }

    required init?(coder: NSCoder) { nil }

    override func updateLayer() {
        super.updateLayer()
        guard let layer, let inverseFilter else {
            layer?.isHidden = true
            return
        }
        layer.isHidden = !configure(layer, filter: inverseFilter)
    }

    private func configure(_ layer: CALayer, filter: NSObject) -> Bool {
        if NSStringFromClass(type(of: layer)) == "CABackdropLayer" {
            guard layer.responds(to: NSSelectorFromString("setScale:")) else { return false }
            layer.filters = [filter]
            // 反相需要保留像素细节，不能沿用毛玻璃材质的低分辨率采样。
            layer.setValue(1.0, forKey: "scale")
            layer.backgroundColor = nil
            return true
        }
        var containsBackdrop = false
        for child in layer.sublayers ?? [] {
            let contains = configure(child, filter: filter)
            // 系统负责背景图层的生命周期，只去掉会改变反相颜色的材质染色层。
            child.isHidden = !contains
            containsBackdrop = containsBackdrop || contains
        }
        layer.backgroundColor = nil
        return containsBackdrop
    }
}
