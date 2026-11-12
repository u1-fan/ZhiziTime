# 智子时间

一个运行在 macOS 桌面上的智子风格实时悬浮时钟。

应用启动后会在主屏幕右上角显示日期和时间。浮层使用跨 Space 的置顶面板，因此切换桌面或进入全屏应用时仍会显示；应用本身以菜单栏图标运行，不会在 Dock 中占位。

## 运行要求

- macOS 13 或更高版本
- Swift 6 / Xcode 15 或更高版本
- [Taskfile.yml](Taskfile.yml) 可选，用于统一构建命令

## 构建和运行

```bash
task check   # 检查包结构并编译 debug 版本
task app     # 构建 dist/ZhiziTime.app
task run     # 构建后打开应用
```

也可以直接运行：

```bash
swift run ZhiziTime
```

菜单栏中的时钟图标提供“隐藏智子时间”“显示智子时间”和“退出”操作。当前版本默认使用主屏幕右上角，窗口不接收鼠标事件，因此不会挡住桌面上的正常操作。

## 设计说明

- 日期、时分秒使用系统本地时区，并每秒更新。
- 透明浮层由 AppKit `NSPanel` 管理，SwiftUI 负责视觉内容。
- `.canJoinAllSpaces` 和 `.fullScreenAuxiliary` 让浮层跨桌面和全屏空间显示。
- 菜单栏应用通过 `LSUIElement` 隐藏 Dock 图标。
