# Wallhaven for Windows

Windows 版使用 Qt 6、C++ 和 QML，提供 Wallhaven 搜索、筛选、分页、预览、下载、
本地图库和设置桌面壁纸功能。

## 系统要求

- Windows 10 1809+ 或 Windows 11 x64
- Visual Studio 2022 Build Tools
  - Desktop development with C++
  - Windows 10/11 SDK
- CMake
- Ninja
- Qt 6.8.3 MSVC 2022 x64
  - Qt Declarative / QML / Quick
  - Qt Image Formats

本机初始化使用：

```powershell
winget install --id Microsoft.VisualStudio.2022.BuildTools --exact
winget install --id Kitware.CMake --exact
winget install --id Ninja-build.Ninja --exact
python -m pip install --user aqtinstall
python -m aqt install-qt windows desktop 6.8.3 win64_msvc2022_64 -O C:\Qt -m qtimageformats
```

如果 `aqtinstall` 在包含中文的当前目录中解压失败，请先切换到仅含 ASCII 字符的临时目录再执行
Qt 安装命令。

## 构建

```powershell
Windows\build.ps1 -Configuration Debug
```

生成可分发的 Release 目录：

```powershell
Windows\build.ps1 -Configuration Release -Package
```

可执行文件位于生成目录的 `bin\WallhavenWindows.exe`。

脚本会自动检测 MSVC、CMake 和 Ninja。Qt 默认路径是
`C:\Qt\6.8.3\msvc2022_64`，也可以通过 `-QtRoot` 指定。

Qt 6.8 的 QML 扫描工具在部分中文路径下会发生转码错误。构建脚本会在必要时自动建立位于
`%LOCALAPPDATA%\WallhavenBuild\source` 的目录联接，源码和输出仍保存在原仓库中。

## Windows 集成

- 壁纸：Windows `IDesktopWallpaper` COM API，当前应用到所有显示器并使用填充模式。
- API Key：Windows Credential Manager，不写入普通偏好设置。
- 偏好：Qt `QSettings`，Windows 下存放在当前用户注册表。
- 下载：默认写入用户图片目录下的 `Wallhaven` 文件夹。
- 目录选择：Qt `QFileDialog` 调用 Windows 原生目录选择器。
- 图标：原创山景图标同时嵌入 Windows EXE，并作为 Qt 窗口图标打包。
