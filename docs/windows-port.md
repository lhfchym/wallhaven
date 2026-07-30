# Windows 移植调研

## 结论

Windows 版本应以 `origin/feat/kubuntu-plasma-bluecurve` 中的 Qt 6 / C++ / QML 客户端为基础，
不要直接移植 `WallhavenMac` 的 SwiftUI 界面。

原因：

- Swift 语言和 SwiftPM 支持 Windows，但 SwiftUI、AppKit 和 Security 是 Apple 平台框架。
- Linux 分支已经实现搜索、分页、缩略图、预览、下载、本地库、偏好、多语言和显示器分辨率检测。
- Qt 6 的 Core、Gui、Network、Qml、Quick 和 QuickControls2 都支持 Windows。
- Linux 客户端中需要重写的主要是 KDE/DBus/KWallet 集成，业务和界面主体可以保留。

预计 Linux 客户端约 75%～80% 的代码可以直接复用。Windows MVP 的主要工作集中在
壁纸设置、凭据存储、目录选择、图标和安装包。

## 路径比较

| 方案 | 可复用程度 | Windows 原生感 | 工程风险 | 建议 |
| --- | ---: | ---: | ---: | --- |
| Qt 6 / C++ / QML，复用 Linux 分支 | 高 | 中 | 低 | 推荐 |
| C# / .NET / WinUI 3 或 WPF 重写 | 低 | 高 | 中 | 仅在原生 UI 优先时考虑 |
| Swift on Windows + Win32 UI 桥接 | 中（仅 Core） | 中 | 高 | 不建议 |

Qt 路径还可以逐步把 macOS 和 Windows/Linux 的行为统一到同一套跨平台控制器中；
.NET 路径会形成第三套业务实现。

## 当前代码与 Windows 映射

### 可直接复用

来自 Linux 分支：

- `Linux/qml/Main.qml`
  - 搜索和筛选
  - 在线图库和下载库
  - 缩略图网格和预览
  - 自动加载下一页并保持滚动位置
  - 中文/英文设置
- `WallpaperController.cpp` 中的平台无关部分
  - Wallhaven API 请求和 JSON 解析
  - 下载、大小限制和原子写入
  - 本地图库扫描和删除
  - 分页、取消旧请求和随机种子
  - 显示器像素分辨率与宽高比计算
  - `QSettings` 偏好保存
- Qt 跨平台能力
  - `QNetworkAccessManager`
  - `QStandardPaths::PicturesLocation`
  - `QDesktopServices::openUrl`
  - `QScreen`

### 需要替换

| Linux 实现 | Windows 实现 |
| --- | --- |
| `Qt6::DBus`、Plasma `evaluateScript`、XDG Wallpaper Portal | Win32 COM `IDesktopWallpaper` |
| `KF6::Wallet` | Windows Credential Manager：`CredWriteW` / `CredReadW` / `CredDeleteW` |
| 启动 `kdialog` 选择目录 | Qt `QFileDialog::getExistingDirectory`，默认使用 Windows 原生对话框 |
| `plasmaAvailable` | 重命名为 `desktopIntegrationAvailable` |
| Plasma/KDE 状态文案 | Windows 桌面集成文案 |
| Bluecurve/Linux 图标名称 | Qt 标准主题图标或随应用打包的 SVG 图标 |
| `WallhavenLinux` 名称和默认目录 | `WallhavenWindows` 或统一为 `Wallhaven` |

## 推荐目录结构

先从 Linux 功能分支创建 Windows 实现分支，再做平台拆分：

```text
Desktop/
  CMakeLists.txt
  qml/
    Main.qml
  src/
    main.cpp
    WallpaperController.cpp
    WallpaperController.h
    platform/
      DesktopWallpaperService.h
      CredentialStore.h
      windows/
        WindowsDesktopWallpaperService.cpp
        WindowsCredentialStore.cpp
      linux/
        PlasmaDesktopWallpaperService.cpp
        KWalletCredentialStore.cpp
```

如果第一期只要求 Windows，可先建立 `Windows/`，复制 Linux 客户端后删去 DBus/KWallet；
但应立即抽出 `DesktopWallpaperService` 和 `CredentialStore` 两个接口，避免平台条件编译散落在控制器里。

## Windows 平台实现

### 设置壁纸

使用 Windows 8 及以上桌面应用支持的 `IDesktopWallpaper`：

1. `CoInitializeEx` 初始化 COM。
2. `CoCreateInstance(CLSID_DesktopWallpaper, ..., IID_IDesktopWallpaper, ...)`。
3. 第一版对所有显示器调用 `SetWallpaper(nullptr, absolutePath)`。
4. 后续如需逐屏设置，通过 `GetMonitorDevicePathCount` 和 `GetMonitorDevicePathAt` 枚举显示器，
   再向 `SetWallpaper(monitorId, absolutePath)` 传入对应 ID。
5. 将 `HRESULT` 转成可读错误并返回给控制器，不要仅根据 API 调用发出成功提示。

源图片必须先下载到本地，并传入规范化的绝对 Windows 路径。

### API Key

使用 Windows Credential Manager 存储，建议：

- `TargetName`: `dev.local.wallhaven/api-key`
- `Type`: `CRED_TYPE_GENERIC`
- `Persist`: `CRED_PERSIST_LOCAL_MACHINE`
- 保存：`CredWriteW`
- 读取：`CredReadW`
- 清空：`CredDeleteW`

不要把 API Key 放入 `QSettings`；Windows 下 `QSettings::NativeFormat` 默认写入注册表，但注册表设置
不等于安全凭据存储。

### 文件与偏好

- 默认下载目录继续使用 `QStandardPaths::PicturesLocation`，子目录改成 `Wallhaven`。
- 普通偏好继续用 `QSettings`；Windows 下会落到当前用户注册表。
- 目录选择直接使用 `QFileDialog`，不再启动外部进程。
- 打开网页和文件夹继续使用 `QDesktopServices::openUrl`。

### 界面

QML 布局可以保留，但需要：

- 移除 “Linux / KDE Plasma / Bluecurve” 专属标题和说明。
- 把 `plasmaAvailable` 相关命名改成平台无关命名。
- 为图标提供资源内 fallback，避免 Windows 图标主题中不存在 `stock-*` 名称时按钮无图标。
- 验证 100%、125%、150%、200% DPI 和长中文路径。
- 第一版不必做托盘常驻；先完成窗口内搜索、下载和设壁纸闭环。

## 实现状态

`codex/windows-port` 已基于 Linux Qt 客户端完成第一版 Windows 移植，代码位于 `Windows/`：

- `IDesktopWallpaper` 已用于全显示器壁纸设置。
- Windows Credential Manager 已用于 API Key 的保存、读取和删除。
- KDE/DBus/KWallet 依赖已移除。
- Windows 原生目录选择、默认图片目录和平台状态文案已接入。
- 原创 Windows 山景图标已嵌入 EXE，并作为 Qt 窗口图标使用。
- Release 发布目录已通过 `windeployqt` 自动收集 Qt DLL、QML 模块和平台插件。

本机已安装并验证：

- Windows 10 1809+ 或 Windows 11 x64
- Visual Studio 2022 C++ Build Tools 和 Windows SDK
- Qt 6.8.3 MSVC 2022 x64
- CMake 4.4.1 和 Ninja 1.13.2

## 构建与打包

推荐使用仓库内脚本：

```powershell
Windows\build.ps1 -Configuration Debug
Windows\build.ps1 -Configuration Release -Package
```

脚本会处理 Qt QML 扫描器在中文仓库路径下的转码问题，并在 `Windows/dist/` 生成包含
Qt DLL、QML 模块和 `qwindows` 平台插件的发布目录。首个内部测试包可使用 ZIP；
稳定后再增加 Inno Setup、WiX/MSI 或 MSIX。发布前还需处理代码签名和 Qt 许可证合规。

## 实施顺序

### 阶段 1：可运行 Windows MVP

1. 从 `origin/feat/kubuntu-plasma-bluecurve` 建立实际开发分支。
2. 复制/重构 Linux Qt 客户端为跨平台 Desktop 客户端。
3. 移除 DBus 和 KWallet 依赖，使项目在 Windows 编译。
4. 接入 `IDesktopWallpaper`。
5. 接入 Windows Credential Manager。
6. 修复 Windows 文案、目录选择、图标和路径。

### 阶段 2：质量验证

1. 搜索、分页、刷新和请求取消。
2. JPG、PNG、WebP 下载、预览和设壁纸。
3. 单屏、扩展双屏、不同 DPI 和更换主显示器。
4. 中文用户名、空格路径和超长路径。
5. 无 API Key、错误 API Key、断网、超时和下载中断。
6. API Key 不出现在日志、注册表普通设置或崩溃信息中。

### 阶段 3：分发

1. Release 构建和 `windeployqt`。
2. 在干净 Windows Sandbox/虚拟机测试。
3. 增加安装、升级和卸载流程。
4. 代码签名。
5. 如需公开分发，再增加 WinGet 清单。

## 风险

- Linux 功能分支尚未合并到 `main`；实际开发分支应明确以它为基线，避免重复实现。
- Qt 动态分发体积会明显大于原生 Swift/macOS 包。
- Qt 开源版本通常采用 LGPL/GPL 双许可证；发布方式、动态链接、许可证文本和 Qt 源码获取方式
  需要按所选许可证落实，商业闭源分发应先做许可证评估。
- `IDesktopWallpaper` 从 Windows 8 起可用。如果要支持更旧系统，需要
  `SystemParametersInfo(SPI_SETDESKWALLPAPER)` fallback；当前不建议扩大到该范围。
- Windows Credential Manager 的错误码和凭据大小限制需要显式处理。

## 完成标准

Windows MVP 满足以下条件即可认为移植闭环完成：

- 能启动并自动按主显示器像素分辨率查询。
- 能搜索、筛选、分页和预览。
- 能下载到用户图片目录并浏览本地库。
- 能把下载后的图片设为所有显示器壁纸。
- API Key 安全存储，重启后仍可读取，清空后确实删除。
- 在没有 Qt 开发环境的干净 Windows 机器上可安装和运行。

## 参考资料

- [Qt for Windows](https://doc.qt.io/qt-6/windows.html)
- [Qt for Windows - Deployment](https://doc.qt.io/qt-6/windows-deployment.html)
- [QSettings](https://doc.qt.io/qt-6/qsettings.html)
- [QStandardPaths](https://doc.qt.io/qt-6/qstandardpaths.html)
- [IDesktopWallpaper::SetWallpaper](https://learn.microsoft.com/en-us/windows/win32/api/shobjidl_core/nf-shobjidl_core-idesktopwallpaper-setwallpaper)
- [CredWriteW](https://learn.microsoft.com/en-us/windows/win32/api/wincred/nf-wincred-credwritew)
- [Swift Windows Workgroup](https://www.swift.org/blog/announcing-windows-workgroup/)
- [SwiftUI platform overview](https://developer.apple.com/swiftui/)
- [Qt open-source LGPL obligations](https://www.qt.io/development/open-source-lgpl-obligations)
