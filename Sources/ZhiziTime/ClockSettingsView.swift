import SwiftUI

struct ClockSettingsView: View {
    @ObservedObject var settings: ClockSettings
    @State private var showsFontLibrary = false

    var body: some View {
        VStack(spacing: 0) {
            header
            terminalStrip
            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 12) {
                    appearance
                    HStack(alignment: .top, spacing: 12) {
                        placement
                        timeFormat
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)

                ClockPreviewConsole(settings: settings)
                    .frame(width: 330)
            }
            .padding(18)
            .frame(maxHeight: .infinity, alignment: .top)
            footer
        }
        .foregroundStyle(ConsoleStyle.text)
        .tint(ConsoleStyle.cyan)
        .background {
            ConsoleStyle.background
                .overlay(alignment: .topTrailing) {
                    RadialGradient(
                        colors: [ConsoleStyle.cyan.opacity(0.13), .clear],
                        center: .topTrailing,
                        startRadius: 0,
                        endRadius: 650
                    )
                }
                .overlay { ObservatoryBackdrop() }
                .ignoresSafeArea()
        }
        .preferredColorScheme(settings.appearance.colorScheme)
        .frame(minWidth: 980, idealWidth: 1040, minHeight: 720, idealHeight: 760)
    }

    private var header: some View {
        HStack(spacing: 15) {
            OrbitalMark()
            VStack(alignment: .leading, spacing: 5) {
                Text("智子时间")
                    .font(.system(size: 26, weight: .light))
                Text("桌面时钟设置")
                    .font(.system(size: 10))
                    .foregroundStyle(ConsoleStyle.muted)
            }
            Spacer()
            HStack(spacing: 2) {
                ForEach(ConsoleAppearance.allCases) { appearance in
                    Button {
                        settings.appearance = appearance
                    } label: {
                        Label(appearance.title, systemImage: appearance.symbol)
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 13)
                            .padding(.vertical, 10)
                            .foregroundStyle(settings.appearance == appearance ? ConsoleStyle.background : ConsoleStyle.muted)
                            .background(settings.appearance == appearance ? ConsoleStyle.cyan : .clear, in: HUDCutout(cut: 7))
                    }
                    .buttonStyle(ConsoleButtonStyle())
                    .accessibilityLabel(appearance.title)
                    .accessibilityAddTraits(settings.appearance == appearance ? .isSelected : [])
                }
            }
            .padding(3)
            .background(ConsoleStyle.cyan.opacity(0.08), in: HUDCutout(cut: 9))
            .overlay { HUDCutout(cut: 9).stroke(ConsoleStyle.line) }
            .padding(.trailing, 15)
            VStack(alignment: .trailing, spacing: 7) {
                HStack(spacing: 6) {
                    Circle().fill(ConsoleStyle.cyan).frame(width: 5, height: 5)
                    Text("时钟运行中")
                        .font(.system(size: 11))
                }
                Text("按系统时间更新")
                    .font(.system(size: 9))
                    .foregroundStyle(ConsoleStyle.muted)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 19)
        .padding(.bottom, 21)
        .background(WindowDragArea())
    }

    private var terminalStrip: some View {
        HStack(spacing: 12) {
            HStack(spacing: 3) {
                ForEach(0..<8) { index in
                    Rectangle()
                        .fill(index < 3 ? ConsoleStyle.cyan : ConsoleStyle.cyan.opacity(0.2))
                        .frame(width: 5, height: 12)
                        .rotationEffect(.degrees(15))
                }
            }
            Text("显示设置")
                .font(.system(size: 10, weight: .medium))
            Text("字体、颜色、位置和时间格式")
                .font(.system(size: 9))
                .foregroundStyle(ConsoleStyle.muted)
            Spacer()
            Text("自动保存")
                .font(.system(size: 10))
            Image(systemName: "externaldrive.badge.checkmark")
                .font(.system(size: 11))
                .foregroundStyle(ConsoleStyle.amber)
        }
        .foregroundStyle(ConsoleStyle.cyan)
        .padding(.horizontal, 28)
        .padding(.vertical, 9)
        .background(ConsoleStyle.cyan.opacity(0.065))
        .overlay(alignment: .top) { Rectangle().fill(ConsoleStyle.line).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(ConsoleStyle.line).frame(height: 1) }
    }

    private var appearance: some View {
        ConsolePanel(index: "01", title: "显示样式", code: "外观") {
            VStack(spacing: 15) {
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        fieldLabel("字体", detail: "字体")
                        Button {
                            showsFontLibrary = true
                        } label: {
                            HStack {
                                Text(settings.fontName).lineLimit(1)
                                Spacer(minLength: 4)
                                Image(systemName: "textformat")
                            }
                            .font(.system(size: 12))
                            .padding(10)
                            .frame(maxWidth: .infinity)
                            .background(ConsoleStyle.background, in: HUDCutout(cut: 7))
                            .overlay { HUDCutout(cut: 7).stroke(ConsoleStyle.line) }
                        }
                        .buttonStyle(ConsoleButtonStyle())
                        .accessibilityLabel("选择字体，当前\(settings.fontName)")
                        .popover(isPresented: $showsFontLibrary, arrowEdge: .bottom) {
                            FontLibraryView(settings: settings)
                                .preferredColorScheme(settings.appearance.colorScheme)
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        fieldLabel("字体颜色", detail: "颜色")
                        consoleMenu("字体颜色", value: settings.colorMode.title) {
                            Picker("字体颜色", selection: $settings.colorMode) {
                                ForEach(ClockColor.allCases) { color in
                                    Text(color.title).tag(color)
                                }
                            }
                        }
                    }
                }
                HStack {
                    fieldLabel("字重", detail: "粗细")
                        .frame(width: 90)
                    ForEach(ClockWeight.allCases) { weight in
                        Button {
                            settings.fontWeight = weight
                        } label: {
                            Text(weight.title)
                                .font(.system(size: 11, weight: weight.swiftUIWeight))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .foregroundStyle(settings.fontWeight == weight ? ConsoleStyle.background : ConsoleStyle.muted)
                                .background(settings.fontWeight == weight ? ConsoleStyle.cyan : ConsoleStyle.background, in: HUDCutout(cut: 5))
                        }
                        .buttonStyle(ConsoleButtonStyle())
                        .accessibilityAddTraits(settings.fontWeight == weight ? .isSelected : [])
                    }
                }
                if settings.colorMode == .adaptive {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NativeInversion.isAvailable ? "原生反相 · 无需屏幕录制" : "当前系统不支持原生反相，请选择固定颜色")
                            .font(.system(size: 10))
                            .foregroundStyle(ConsoleStyle.cyan)
                        Text("由系统更新文字区域的背景反相，应用不采集桌面画面。使用系统非公开合成接口，系统升级后可能需要适配。")
                            .font(.system(size: 10))
                            .foregroundStyle(ConsoleStyle.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Rectangle().fill(ConsoleStyle.line).frame(height: 1)
                consoleSlider(
                    "字号", detail: "大小", value: $settings.fontSize,
                    range: 16...120, step: 1, readout: "\(Int(settings.fontSize))", unit: "PT"
                )
                consoleSlider(
                    "不透明度", detail: "透明度", value: $settings.opacity,
                    range: 0.05...1, step: 0.01, readout: "\(Int((settings.opacity * 100).rounded()))", unit: "%"
                )
            }
        }
    }

    private var placement: some View {
        ConsolePanel(index: "02", title: "空间定位", code: "位置") {
            HStack(spacing: 22) {
                positionMap
                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 7) {
                        Image(systemName: "scope")
                            .foregroundStyle(ConsoleStyle.cyan)
                        Text(settings.position.title)
                            .font(.system(size: 16, weight: .medium))
                    }
                    Text("选择锚点，定位桌面上的时间。")
                        .font(.system(size: 11))
                        .foregroundStyle(ConsoleStyle.muted)
                    Text("跨桌面显示 · 鼠标穿透")
                        .font(.system(size: 10))
                        .foregroundStyle(ConsoleStyle.muted)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var positionMap: some View {
        ZStack {
            HUDCutout(cut: 9)
                .fill(ConsoleStyle.background)
            ConsoleGrid().clipShape(HUDCutout(cut: 9))
            OrbitalReticle().opacity(0.35).padding(1)
            HUDCutout(cut: 9)
                .stroke(ConsoleStyle.line, lineWidth: 1)
            ForEach(ClockPosition.allCases) { position in
                Button {
                    settings.position = position
                } label: {
                    ZStack {
                        HUDCutout(cut: 4)
                            .fill(settings.position == position ? ConsoleStyle.cyan.opacity(0.16) : .clear)
                        Image(systemName: settings.position == position ? "viewfinder" : "plus")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(settings.position == position ? ConsoleStyle.cyan : ConsoleStyle.muted)
                    }
                    .frame(width: 30, height: 26)
                }
                .buttonStyle(ConsoleButtonStyle())
                .accessibilityLabel("位置：\(position.title)")
                .accessibilityAddTraits(settings.position == position ? .isSelected : [])
                .help(position.title)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: position.alignment)
                .padding(7)
            }
        }
        .frame(width: 156, height: 91)
    }

    private var timeFormat: some View {
        ConsolePanel(index: "03", title: "时间格式", code: "格式") {
            VStack(alignment: .leading, spacing: 10) {
                consoleMenu("时间格式", value: settings.format.title) {
                    Picker("时间格式", selection: $settings.format) {
                        ForEach(ClockFormat.allCases) { format in
                            Text(format.title).tag(format)
                        }
                    }
                }
                if settings.format == .custom {
                    TextField("例如 Y-m-d H:i:s", text: $settings.customFormat)
                        .font(ConsoleStyle.telemetry(12))
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("自定义时间格式")
                    Text("Y 年 · m 月 · d 日 · H 时 · i 分 · s 秒\n也支持 yyyy-MM-dd HH:mm:ss。")
                        .font(.system(size: 10))
                        .foregroundStyle(ConsoleStyle.muted)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("使用系统本地时区，每秒同步。")
                        .font(.system(size: 11))
                        .foregroundStyle(ConsoleStyle.muted)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(ConsoleStyle.cyan)
            Text("更改已即时保存")
                .font(.system(size: 11))
            Spacer()
            Button {
                settings.reset()
            } label: {
                Label("恢复默认", systemImage: "arrow.counterclockwise")
                    .font(.system(size: 11))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(ConsoleStyle.cyan.opacity(0.06), in: RoundedRectangle(cornerRadius: 5))
                    .overlay {
                        RoundedRectangle(cornerRadius: 5).strokeBorder(ConsoleStyle.line)
                    }
            }
            .buttonStyle(ConsoleButtonStyle())
            .help("恢复默认字体、颜色、位置与时间格式")
        }
        .foregroundStyle(ConsoleStyle.muted)
        .padding(.horizontal, 28)
        .padding(.vertical, 12)
        .background(ConsoleStyle.background.opacity(0.95))
        .overlay(alignment: .top) {
            Rectangle().fill(ConsoleStyle.line).frame(height: 1)
        }
    }

    private func fieldLabel(_ title: String, detail: String) -> some View {
        HStack {
            Text(title).font(.system(size: 11))
            Spacer()
            Text(detail)
                .font(ConsoleStyle.telemetry(8))
                .tracking(1)
                .foregroundStyle(ConsoleStyle.muted)
        }
    }

    private func consoleMenu<Content: View>(
        _ title: String, value: String, @ViewBuilder content: () -> Content
    ) -> some View {
        Menu {
            // 内联选择器直接展示选项，避免系统再生成一层同名子菜单。
            content().pickerStyle(.inline)
        } label: {
            Text(value)
                .font(.system(size: 12))
                .lineLimit(1)
        }
        .menuStyle(.borderlessButton)
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(ConsoleStyle.background, in: HUDCutout(cut: 7))
        .overlay { HUDCutout(cut: 7).stroke(ConsoleStyle.line) }
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }

    private func consoleSlider(
        _ title: String, detail: String, value: Binding<Double>,
        range: ClosedRange<Double>, step: Double, readout: String, unit: String
    ) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 12))
                Text(detail)
                    .font(ConsoleStyle.telemetry(8))
                    .foregroundStyle(ConsoleStyle.muted)
            }
            .frame(width: 76, alignment: .leading)
            // 连续滑轨避免大量离散刻度挤在一起，写入时仍保留原来的精度。
            Slider(value: Binding(
                get: { value.wrappedValue },
                set: { value.wrappedValue = min(range.upperBound, max(range.lowerBound, ($0 / step).rounded() * step)) }
            ), in: range)
                .accessibilityLabel(title)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(readout)
                    .font(ConsoleStyle.telemetry(20))
                    .foregroundStyle(ConsoleStyle.cyan)
                    .monospacedDigit()
                Text(unit)
                    .font(ConsoleStyle.telemetry(9))
                    .foregroundStyle(ConsoleStyle.muted)
            }
            .frame(width: 65, alignment: .trailing)
            .padding(.vertical, 5)
            .padding(.horizontal, 7)
            .background(ConsoleStyle.cyan.opacity(0.07), in: HUDCutout(cut: 6))
            .accessibilityElement(children: .combine)
        }
    }
}
