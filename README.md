# Wallhaven for macOS

用原生 macOS 界面浏览 [wallhaven.cc](https://wallhaven.cc)，预览、下载并设置桌面壁纸。

本分支为 `mac`，使用 SwiftUI 和 AppKit。应用名称为 **WallhavenMac**，支持从 Dock 和菜单栏入口打开。

![WallhavenMac 的在线壁纸图库与显示器适配预览](docs/screenshots/macos-gallery.png)

*本机运行 WallhavenMac 0.2.0 的实际截图。*

## 功能

- 关键词搜索，以及普通、动漫、人物分类和内容分级筛选。
- 最热、最新、收藏排行、随机、浏览量和相关性排序。
- 按显示器像素分辨率搜索，可启用严格宽高比匹配。
- 缩略图网格、显示器适配预览、滚动加载和来源页面入口。
- 原图下载、本地下载库、Finder 定位及将本地图片移至废纸篓。
- 将选中壁纸应用到当前连接的所有显示器。
- 中文 / 英文界面、自定义下载目录、钥匙串 API Key 存储。

“收藏排行”是 Wallhaven 的收藏数量排名，不是个人收藏同步。

## 环境要求

| 用途 | 要求 |
| --- | --- |
| 运行应用 | macOS 14 或更新版本 |
| SwiftPM 构建与测试 | Swift 6.2+ 工具链及 macOS SDK |
| 生成 `.app` 和 DMG | 完整 Xcode、XcodeGen |
| 可选代码检查 | SwiftFormat、SwiftLint |

## 获取与运行

克隆本平台分支：

```sh
git clone --branch mac https://github.com/lhfchym/wallhaven.git wallhaven
cd wallhaven
swift build
swift run WallhavenMac
```

以下命令均在仓库根目录执行。SwiftPM 可以直接构建和运行，不需要先生成 Xcode 工程。

### 构建应用包

安装 XcodeGen 后，生成工程并构建：

```sh
xcodegen generate
xcodebuild -project WallhavenMac.xcodeproj \
  -scheme WallhavenMac \
  -configuration Debug \
  -derivedDataPath build/DerivedData build
open build/DerivedData/Build/Products/Debug/WallhavenMac.app
```

`project.yml` 是 Xcode 工程配置源，生成的 `.xcodeproj` 不纳入版本控制。

### 打包 DMG

```sh
Scripts/package_dmg.sh
```

输出为 `dist/WallhavenMac-<版本号>.dmg`。打开 DMG 后，将应用拖入“应用程序”文件夹。

脚本默认递增 `project.yml` 中 `MARKETING_VERSION` 的补丁号，并更新构建号。若只需要按指定版本打包，不触发自动递增，可使用：

```sh
VERSION=0.2.0 Scripts/package_dmg.sh
```

`VERSION` 覆盖打包脚本使用的版本和 DMG 文件名；应用内版本仍来自 `project.yml`，发布时应保持两者一致。当前脚本用于本地测试打包，不包含 Developer ID 分发签名和公证流程。

`Scripts/install_local_app.sh` 可构建并安装到 `/Applications/WallhavenMac.app`。它会递增版本、退出正在运行的应用，并替换该路径下的已有副本。

## 开始使用

1. 打开“最热”“最新”或“收藏排行”，也可以输入关键词搜索。
2. 选择分类、内容分级和排序方式，点选图片查看右侧适配预览。
3. 点击“下载”保存原图，或点击“设置为壁纸”下载并应用。
4. 在“已下载”中重新应用图片、在 Finder 中定位文件或删除图片。
5. 点击左下角设置按钮，调整语言、下载目录、宽高比匹配和 API Key。

普通 SFW 搜索无需 API Key。密钥仅在需要受限内容筛选时填写，保存在 macOS 钥匙串中。

## 本地数据

| 数据 | 默认位置或方式 |
| --- | --- |
| 下载的壁纸 | `~/Pictures/WallhavenMac`，可在设置中修改 |
| 浏览与应用历史 | `~/Library/Application Support/WallhavenMac/history.json` |
| 搜索和界面偏好 | `UserDefaults` |
| Wallhaven API Key | macOS 钥匙串 |

下载库中的删除操作会将文件移至废纸篓。设置壁纸会同时更新所有连接的显示器，当前没有逐屏选择入口。

## 开发

```sh
swift test
Scripts/dev.sh
```

`Scripts/dev.sh` 依次执行构建、测试，并在已安装 SwiftLint 时运行检查。可用 `swiftformat .` 格式化代码。

| 路径 | 内容 |
| --- | --- |
| `Sources/WallhavenCore/` | API 模型、搜索参数和显示器匹配逻辑 |
| `Sources/WallhavenMac/` | SwiftUI 界面、AppKit 桌面集成与本地存储 |
| `Tests/WallhavenCoreTests/` | 核心逻辑测试 |
| `Resources/` | 应用图标 |
| `Scripts/` | 开发、版本管理、安装和打包脚本 |

Windows 和 Linux 分别在 `codex/windows-port`、`feat/kubuntu-plasma-bluecurve` 分支维护；项目总览见 `main` 分支。

## 许可证

源代码与项目文档采用 [MIT 许可证](LICENSE)。

壁纸内容来自 Wallhaven，图片权利归各自权利人所有。本项目为非官方客户端。 MIT 许可证不授予这些壁纸图片的使用权。
