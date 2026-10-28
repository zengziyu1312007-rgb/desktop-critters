# Windows 原生工程

Windows 0.9.0，使用 C# / WPF / .NET 10。Mac 工程继续保留在仓库根目录，Windows 在本目录独立构建。

## 使用

下载 Releases 中的 `DesktopCritters-v0.9.0-Windows-x64-Setup.exe`，双击安装后从开始菜单打开“桌面有点脏”。安装包包含运行环境，按当前用户安装，不要求另装 .NET，也不设置开机自启。

也可以下载 `Portable.zip`，解压到独立文件夹并运行 `DesktopCritters.exe`。

控制面板可收起；从任务栏打开面板，或双击系统托盘图标找回。托盘右键也有打开面板、暂停、战报和退出入口。互动时数字1–7切工具，Tab选虫或卵，回车使用，空格暂停，Esc恢复鼠标穿透。Ctrl+0在应用前台时打开面板。

首版包含两阵营、食物缺损、五阶段成长、繁殖、尸体、爆浆、扫把、单挑／围攻／冲撞、蜘蛛与甲虫事件、外交、每日战报和本机存档。当前以主显示器桌面为活动区域，不跨多个显示器铺满；部分DPI组合仍需真人验证。

## 存档

```text
%LOCALAPPDATA%\DesktopCrittersWindows\ecology-windows-v1.json
```

约每15秒及退出时保存。关闭期间不模拟；坏存档保留并阻止覆盖。卸载不删除上述个人数据目录。Windows与Mac目前独立保存，不自动迁移或同步存档。

## 开发构建

需要 Windows、.NET 10 SDK 和 Inno Setup 6：

```powershell
./windows/build.ps1
```

产物位于 `windows/out/release/`，含安装包、免安装ZIP和SHA-256校验文件。脚本会运行核心检查、发布后的EXE检查、透明窗口API自检与WPF离屏渲染，再验证静默安装、从安装目录运行和卸载。

生态核心也可在Mac/Linux的 .NET 10 SDK上验证：

```sh
dotnet run --project tests/WindowsCore.Tests.csproj -c Release
```

`.github/workflows/windows.yml` 使用Windows云端环境构建。窗口API及离屏绘制通过不等于所有真人鼠标拖拽、多屏与显卡组合都已验证。

Windows应用和安装包尚未进行商业证书签名，系统可能显示发布者提示。

## v0.9.0 新玩法

8惊飞成蟑，9标记文件夹背后的藏卵处，0使用杀虫剂。产卵先排出卵，再孵化；文件夹位置由本人手动标记，不读取文件，移动图标需重新标记。外敌选择框可召唤蜘蛛、甲虫、蜈蚣、蛇或老鼠，一次一只。
