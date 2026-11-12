import SwiftUI
import UniformTypeIdentifiers

struct FontLibraryView: View {
    @ObservedObject var settings: ClockSettings
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var showsImporter = false
    @State private var importError: String?
    @FocusState private var searchIsFocused: Bool

    private var matchingFonts: [String] {
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return settings.fonts.filter { search.isEmpty || $0.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("字体库 / TYPE ARCHIVE")
                    .font(.system(size: 16, weight: .medium))
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel("关闭字体选择")
                .help("关闭字体选择（Esc）")
            }
            TextField("搜索已安装或导入的字体", text: $query)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("搜索字体")
                .focused($searchIsFocused)
                .onSubmit {
                    if let font = matchingFonts.first {
                        select(font)
                    }
                }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(matchingFonts, id: \.self) { font in
                            Button {
                                select(font)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(font).font(.system(size: 12)).lineLimit(1)
                                        Text("智子时间 0123456789")
                                            .font(Font(ClockTypography.font(name: font, size: 20, weight: settings.fontWeight)))
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    if settings.fontName == font {
                                        Image(systemName: "checkmark").foregroundStyle(ConsoleStyle.cyan)
                                    }
                                }
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(settings.fontName == font ? ConsoleStyle.cyan.opacity(0.12) : .clear, in: HUDCutout(cut: 5))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("选择字体：\(font)")
                            .accessibilityAddTraits(settings.fontName == font ? .isSelected : [])
                            .id(font)
                        }
                    }
                }
                .onAppear { proxy.scrollTo(settings.fontName, anchor: .center) }
            }
            if matchingFonts.isEmpty {
                Text("没有匹配的字体，可以导入字体文件。")
                    .font(.caption)
                    .foregroundStyle(ConsoleStyle.muted)
            }
            HStack {
                Button("导入字体…") { showsImporter = true }
                Text("支持 .ttf / .otf，仅保存在本应用内。")
                    .font(.caption)
                    .foregroundStyle(ConsoleStyle.muted)
            }
            Text("字体提供的字重样式可能不同；缺少某一字重时由系统匹配最接近的样式。")
                .font(.caption)
                .foregroundStyle(ConsoleStyle.muted)
        }
        .padding(18)
        .frame(width: 420, height: 480)
        .foregroundStyle(ConsoleStyle.text)
        .background(ConsoleStyle.background)
        .tint(ConsoleStyle.cyan)
        .defaultFocus($searchIsFocused, true)
        .task {
            // 弹出面板挂接到窗口后再申请焦点，避免首次输入落到设置窗口。
            await Task.yield()
            searchIsFocused = true
        }
        .fileImporter(isPresented: $showsImporter, allowedContentTypes: [
            UTType(filenameExtension: "ttf") ?? .font,
            UTType(filenameExtension: "otf") ?? .font
        ]) { result in
            do {
                let url = try result.get()
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                try settings.importFont(from: url)
                dismiss()
            } catch {
                importError = error.localizedDescription
            }
        }
        .alert("字体导入失败", isPresented: Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("好") { importError = nil }
        } message: {
            Text(importError ?? "")
        }
    }

    private func select(_ font: String) {
        settings.fontName = font
        dismiss()
    }
}
