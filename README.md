# Wallhaven for Windows

在 Windows 桌面上浏览 [wallhaven.cc](https://wallhaven.cc)，搜索、预览、下载并设置壁纸。

本分支为 `codex/windows-port`，使用 Qt 6、C++20 和 QML，通过 Windows 原生接口设置壁纸并保存凭据。应用名称为 **WallhavenWindows**。

## 功能

- 关键词搜索、分类、内容分级及多种排序方式。
- 按显示器分辨率筛选，可选择严格匹配宽高比。
- 缩略图网格、选中预览和自动加载下一页。
- 原图下载、本地下载库、文件删除及重新应用壁纸。
- 通过 `IDesktopWallpaper` 将图片设置到所有显示器。
- 中文 / 英文界面、原生下载目录选择器和 Windows 凭据管理器集成。

“收藏排行”按 Wallhaven 的收藏数量排序，不是个人收藏夹同步。

## 快速开始

目标系统为 Windows 10 1809+ 或 Windows 11 x64。开发需要 Visual Studio 2022 C++ 工具链、Windows SDK、CMake、Ninja 和 Qt 6.8.3 MSVC 2022 x64。

从仓库页面复制克隆地址，替换 `<REPOSITORY_URL>`，在 PowerShell 中执行：

```powershell
git clone --branch codex/windows-port <REPOSITORY_URL> wallhaven
cd wallhaven
.\Windows\build.ps1 -Configuration Release -Package
```

打包结果位于 `Windows\dist\WallhavenWindows-Release-<时间戳>\`。运行其中的 `bin\WallhavenWindows.exe`，分发时保留整个输出目录。

完整依赖安装、Debug 构建、Qt 路径设置和排错说明见 **[Windows/README.md](Windows/README.md)**。

## 使用说明

从“最热”“最新”或“收藏排行”进入图库，也可以输入关键词搜索。选中图片后可下载、打开来源页面或设为桌面壁纸；“已下载”用于管理本地图片。设置中可调整语言、下载目录、宽高比匹配及可选 API Key。

下载默认保存在系统“图片”目录下的 `Wallhaven` 文件夹。普通 SFW 搜索无需 API Key；填写的密钥保存在 Windows 凭据管理器中。

设置壁纸使用填充模式，并同时应用到所有显示器，当前没有逐屏选择入口。本地下载库的删除操作会直接删除文件。

## 代码入口

| 路径 | 内容 |
| --- | --- |
| `Windows/qml/` | QML 界面 |
| `Windows/src/` | 搜索、下载、本地库、桌面壁纸与凭据集成 |
| `Windows/assets/` | EXE 和窗口图标 |
| `Windows/build.ps1` | 工具链发现、构建与依赖打包 |
| `Windows/CMakeLists.txt` | Windows 构建与安装配置 |

本分支保留了 macOS 和 Linux 的历史代码；Windows 开发以 `Windows/` 为入口。其他平台分别在 `mac` 和 `feat/kubuntu-plasma-bluecurve` 分支维护，项目总览见 `main` 分支。

## 许可证

源代码与项目文档采用 [MIT 许可证](LICENSE)。

壁纸内容来自 Wallhaven，图片权利归各自权利人所有。本项目为非官方客户端。 MIT 许可证不授予这些壁纸图片的使用权。
