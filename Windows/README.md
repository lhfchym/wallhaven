# Windows 构建与使用

[返回分支首页](../README.md)

Windows 客户端使用 Qt 6 / QML 和 C++20，提供壁纸搜索、筛选、预览、下载、本地图库和桌面壁纸设置。开发分支为 `codex/windows-port`，源码入口为 `Windows/`。

以下命令均在仓库根目录的 PowerShell 中执行，Qt 安装示例除外。

## 环境要求

| 依赖 | 要求 |
| --- | --- |
| 目标系统 | Windows 10 1809+ 或 Windows 11，x64 |
| 编译工具链 | Visual Studio 2022 或 Build Tools，安装“使用 C++ 的桌面开发”和 Windows 10/11 SDK |
| CMake | 3.24+ |
| Ninja | 构建工具 |
| Qt | CMake 要求 6.8+；构建脚本默认使用 6.8.3 MSVC 2022 x64 |
| Qt 模块 | Core、Gui、Network、Qml、Quick、QuickControls2、Widgets；建议安装 Image Formats |

### 安装工具

可通过 WinGet 安装构建工具：

```powershell
winget install --id Microsoft.VisualStudio.2022.BuildTools --exact
winget install --id Kitware.CMake --exact
winget install --id Ninja-build.Ninja --exact
```

安装 Build Tools 后，在 Visual Studio Installer 中确认已选中 C++ 桌面开发工作负载和 Windows SDK；仅安装启动器不足以构建项目。

Qt 可使用安装器安装，或在已安装 Python 的环境下通过 aqtinstall 获取脚本默认版本：

```powershell
python -m pip install --user aqtinstall
python -m aqt install-qt windows desktop 6.8.3 win64_msvc2022_64 -O C:\Qt -m qtimageformats
```

如果 aqtinstall 在含中文的当前目录中解压失败，先切换到仅含 ASCII 字符的临时目录再运行 Qt 安装命令。

## 构建

### Debug

```powershell
.\Windows\build.ps1 -Configuration Debug
```

可执行文件位于 `Windows\build-debug\WallhavenWindows.exe`。在开发机直接运行时，需要让 Qt DLL 所在目录可见，例如使用默认 Qt 路径：

```powershell
$env:PATH = "C:\Qt\6.8.3\msvc2022_64\bin;$env:PATH"
.\Windows\build-debug\WallhavenWindows.exe
```

### Release 与分发目录

```powershell
.\Windows\build.ps1 -Configuration Release -Package
```

| 产物 | 路径 |
| --- | --- |
| Release 构建程序 | `Windows\build-release\WallhavenWindows.exe` |
| 带 Qt 运行依赖的分发目录 | `Windows\dist\WallhavenWindows-Release-<时间戳>\` |
| 分发目录内的程序 | `bin\WallhavenWindows.exe` |

脚本通过 CMake 安装规则部署 QML 和 Qt 运行依赖。分发时应保留整个输出目录，可将其压缩为 ZIP；只复制 EXE 会遗漏依赖。该流程生成的是目录式分发包，不生成安装向导。

### 自定义 Qt 路径

```powershell
.\Windows\build.ps1 -Configuration Release -Package -QtRoot "D:\Qt\6.8.3\msvc2022_64"
```

`-QtRoot` 指向包含 `bin\qmake.exe` 的 Qt 目录。脚本会自动发现 MSVC、CMake 和 Ninja，并初始化 x64 MSVC 编译环境。

## 日常使用

1. 从“最热”“最新”“收藏排行”进入图库，或输入关键词搜索。
2. 按分类、内容分级和排序方式筛选，选中图片查看预览。
3. 下载原图，或点击“设为桌面壁纸”下载并应用。
4. 在“已下载”中打开下载目录、再次应用图片或删除本地文件。
5. 在设置中选择语言、下载目录、严格宽高比匹配和可选 API Key。

滚动接近图库底部会自动加载下一页。“收藏排行”按 Wallhaven 的收藏数量排序，不同步个人收藏。

普通 SFW 搜索无需 API Key。需要受限内容筛选时填写自己的 Wallhaven API Key，密钥保存在 Windows 凭据管理器中。

## Windows 集成与数据

| 项目 | 行为 |
| --- | --- |
| 壁纸设置 | `IDesktopWallpaper` COM API，填充模式，同时应用到所有显示器 |
| API Key | Windows Credential Manager，不写入普通偏好设置 |
| 偏好设置 | Qt `QSettings`，存放在当前用户注册表 |
| 下载位置 | 系统“图片”目录下的 `Wallhaven` 文件夹，可在设置中修改 |
| 目录选择 | `QFileDialog` 调用 Windows 原生目录选择器 |
| 图标 | 图标嵌入 EXE，并用于 Qt 应用窗口 |

当前没有逐屏选择壁纸的入口。本地图库中的删除操作会直接删除对应文件。

## 常见问题

**Qt was not found**

检查 Qt 版本和安装目录。默认位置是 `C:\Qt\6.8.3\msvc2022_64`；其他位置通过 `-QtRoot` 指定。应使用 MSVC x64 构建的 Qt，不能替换成 MinGW 版本。

**找不到 MSVC、CMake 或 Ninja**

在 Visual Studio Installer 中安装 C++ 桌面开发工作负载。确认 CMake、Ninja 已安装，必要时重新打开 PowerShell，让更新后的 PATH 生效。

**中文路径导致 QML 扫描失败**

Qt 6.8 的 QML 扫描工具在部分非 ASCII 路径下会出现转码问题。构建脚本检测到这种路径时，会建立 `%LOCALAPPDATA%\WallhavenBuild\source` 目录联接；源码和构建输出仍存放在原仓库。

若该联接已存在且指向另一份仓库，脚本会报错停止。确认已有联接的归属后再处理，或将当前仓库放到仅含 ASCII 字符的路径中。

**运行时提示缺少 Qt DLL 或 QML 模块**

开发运行时检查 Qt 的 `bin` 是否在 PATH 中。分发运行时使用带 `-Package` 参数生成的完整目录，并从其中的 `bin\WallhavenWindows.exe` 启动。

## 源码

- [build.ps1](build.ps1)：工具链发现、目录联接、构建与打包。
- [CMakeLists.txt](CMakeLists.txt)：目标、Windows 资源和 Qt 部署规则。
- [qml/Main.qml](qml/Main.qml)：界面与交互。
- [src/WallpaperController.cpp](src/WallpaperController.cpp)：搜索、下载、本地库及偏好。
- [src/WindowsDesktopWallpaperService.cpp](src/WindowsDesktopWallpaperService.cpp)：桌面壁纸设置。
- [src/WindowsCredentialStore.cpp](src/WindowsCredentialStore.cpp)：凭据存储。

## 许可证

源代码与项目文档采用 [MIT 许可证](../LICENSE)。壁纸图片的权利归各自权利人所有。
