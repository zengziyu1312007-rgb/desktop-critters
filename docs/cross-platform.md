# Mac 与 Windows 版本安排

当前发布版本为原生 Mac 应用；Windows 安装包尚未发布。

## 同一仓库可以维护两个平台

保留 `Sources/`、`Resources/`、`build.sh` 和现有 Mac 发布包。后续新增独立的 `windows/` 工程及 Windows 构建任务，纹理素材、玩法参数、存档字段约定和行为用例可以复用。Windows 版需要实现自己的透明桌面窗口、鼠标穿透、托盘、绘图与安装流程。

当前界面使用 [Apple AppKit](https://developer.apple.com/documentation/appkit)。它是 macOS 的应用框架，因此 `.app` 不能改名为 `.exe` 来运行。Windows 端可使用 [.NET WPF](https://learn.microsoft.com/en-us/dotnet/desktop/wpf/overview/) 与 Windows 桌面 API 实现相同玩法。生态与动画按现有用例移植，不把新增一个构建命令当成已完成移植。

## 统一下载入口

同一个 Releases 版本页面可以分别附带：

- `DesktopCritters-vX.Y.Z-macOS-arm64.zip`
- `DesktopCritters-vX.Y.Z-Windows-x64-Setup.exe`

下载页面识别访问者系统后突出对应按钮，并始终提供手动选择。浏览器系统信息有兼容性和隐私限制，不能依赖单一字段；例如 [`navigator.userAgentData`](https://developer.mozilla.org/en-US/docs/Web/API/Navigator/userAgentData) 并非所有浏览器都支持。还需处理手机、未知系统及芯片类型无法确认的情况。

识别和推荐下载可以自动进行；用户仍需启动对应系统的安装程序并完成系统确认。一个文件不能同时作为 Windows EXE 和 macOS App 原生运行，也不自动静默安装软件。

## 现有 Mac 安装的兼容边界

- Windows 工程独立新增，不替换现有 Mac 应用或旧版本附件。
- Mac 的 Bundle ID `cn.peterai.desktopcritters`、应用名和本机存档位置保持一致，Windows 使用自己的应用标识与本地存储目录。
- Mac 与 Windows 分别构建、签名、测试；任一平台构建失败不删除另一平台的既有下载包。
- 首个 Windows 包先验证 Windows 10/11 x64、桌面透明与输入切换、不同缩放比例、多屏、保存恢复和退出行为；通过实机验证后再发布。
- 当前 Mac 包支持 Apple Silicon；Intel Mac 不应被自动推荐为已支持。

v0.7.3 的爆浆逻辑包含可序列化的污渍与液滴轨迹，Windows 移植时可沿用其参数和行为验收要求，绘制由 Windows 端实现。
