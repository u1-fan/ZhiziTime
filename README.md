# 智子时间

一个运行在 macOS 桌面上的智子风格实时悬浮时钟。

应用启动后默认在主屏幕居中显示日期和时间。浮层使用跨 Space 的置顶面板，因此切换桌面或进入全屏应用时仍会显示；应用本身以菜单栏图标运行，不会在 Dock 中占位。

## 运行要求

- macOS 13 或更高版本
- Swift 6.0 或更高版本（使用 Xcode 时需 Xcode 16 或更高版本）
- Python 3.9 或更高版本，用于本地应用打包、校验和安装
- [Task](https://taskfile.dev/)，用于执行 [Taskfile.yml](Taskfile.yml) 中的工作流

## 构建和运行

```bash
task                     # 显示任务列表
task macos:doctor        # 显示工具版本及 macOS SDK 路径
task macos:check         # 检查包结构并编译 debug 版本
task macos:test          # 运行 Swift 渲染回归测试和 macOS 工作流测试
task macos:build         # 只构建当前架构的 release 可执行文件
task macos:app           # 构建并打包 dist/ZhiziTime.app，使用临时签名并校验
task macos:verify        # 校验已有 .app，不构建或启动
task macos:install       # 将已有 .app 安装到 ~/Applications，不构建或启动
task macos:launch        # 打开已有 .app，最多等待 10 秒确认对应路径的进程
task macos:run           # 按顺序执行 macos:app、macos:launch
task macos:logs          # 持续查看应用的系统日志，按 Ctrl-C 退出
task macos:workflow:test # 用替身命令验证打包、安装回滚和启动判断
task macos:clean         # 删除仓库内的 .build 和 dist
```

所有任务仅在 macOS 上执行。从仓库子目录调用时，工作目录仍固定在仓库根目录。
`check`、`build` 和 `app` 不启动或停止应用，也不运行测试。`test` 按顺序运行 Swift 测试和工作流测试；也可以用 `swift test` 单独运行 Swift 测试。
当前包没有外部依赖；以后添加依赖后，SwiftPM 构建可能需要下载依赖。

`app` 在临时目录中组装应用，使用 `codesign --sign -` 添加临时签名，不使用开发者证书，再检查 Bundle ID、可执行文件、图标和签名。校验通过后才替换旧产物。产物只包含当前构建架构，供本机使用；不包含 Developer ID 签名、公证、上传或自动更新发布流程。

`install` 先校验已有产物，再复制到目标目录中的临时位置。复制或验签失败不会覆盖旧应用；替换后再次校验，失败则恢复旧应用。目标应用正在运行时拒绝替换，请先从菜单栏退出。打包也会拒绝替换正在运行的目标 `.app`。

可以指定安装目录和已有应用路径：

```bash
task macos:install INSTALL_DIR="/Applications"
task macos:install INSTALL_DIR="临时 安装" APP_DIR="dist/ZhiziTime.app"
task macos:launch APP_DIR="$HOME/Applications/ZhiziTime.app"
```

`BUILD_DIR` 默认为 `.build/release`，表示打包时读取可执行文件的目录，不改变 SwiftPM 构建位置；`APP_DIR` 默认为 `dist/ZhiziTime.app`，`INSTALL_DIR` 默认为 `~/Applications`。相对路径均以仓库根目录为基准，路径含空格或中文时需加引号。Task 命令行传入的变量优先于宿主同名环境变量；任务不透传 `--` 后的额外参数，也不自动提权。`clean` 只清理仓库内默认产物，不清理自定义路径或已安装应用。

`launch` 先校验应用，再通过绝对路径打开，并轮询该包内可执行文件对应的进程。确认进程存在不代表界面、菜单和跨 Space 行为已经通过验收。`logs` 只筛选进程名为 `ZhiziTime` 的系统日志；当前应用没有专门的日志埋点，可能没有输出。

不使用 Task 时，也可以先构建并打包，再通过应用包启动：

```bash
swift build -c release --product ZhiziTime
python3 scripts/macos.py package --binary .build/release/ZhiziTime --app dist/ZhiziTime.app
python3 scripts/macos.py launch --app dist/ZhiziTime.app
```

菜单栏中的时钟图标提供“设置…”“隐藏时间”“显示时间”和“退出”操作。应用默认在主屏幕居中显示时间，浮层不接收鼠标事件，因此不会挡住桌面上的正常操作。

设置页采用科幻观测终端风格，支持日间与夜间模式，并记住上次选择。可以调整字体、导入 `.ttf` / `.otf` 字体、细体/正常/粗体、颜色、字号、不透明度、五个屏幕位置及时间格式；所有设置即时保存。桌面反相由系统背景合成器处理文字区域，无需屏幕录制权限，不采集桌面图像；应用仅在文字或布局变化时更新文字遮罩。该功能依赖非公开的系统合成接口，系统升级后可能需要适配，接口不可用时请选择固定颜色。右侧按主屏幕比例预览桌面效果，预览背景可独立切换深浅。设置窗口激活时也可以通过 `⌘,` 再次打开设置。

界面规范见 [DESIGN.md](DESIGN.md)。

## 设计说明

- 日期、时分秒使用系统本地时区，并每秒更新。
- 透明浮层由 AppKit `NSPanel` 和原生文字视图渲染，SwiftUI 负责设置界面和桌面预览。
- `.canJoinAllSpaces` 和 `.fullScreenAuxiliary` 让浮层跨桌面和全屏空间显示。
- 菜单栏应用通过 `LSUIElement` 隐藏 Dock 图标。
