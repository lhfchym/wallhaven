# Wallhaven for Linux

面向 KDE Plasma 的 [wallhaven.cc](https://wallhaven.cc) 桌面客户端：搜索、预览和下载壁纸，再将图片应用到 Plasma 桌面。

本分支为 `feat/kubuntu-plasma-bluecurve`，使用 Qt 6、C++20 和 QML，以 Kubuntu 26.04 LTS、KDE Plasma 和 Wayland 为目标环境。界面采用 Bluecurve 风格，桌面操作通过 KDE 服务集成。

## 功能

- 关键词搜索、分类、内容分级及多种排序方式。
- 按显示器分辨率筛选，可选择严格匹配宽高比。
- 壁纸网格与选中预览，滚动加载下一页时保留当前位置。
- 原图下载、本地下载库、文件删除和再次应用壁纸。
- 通过 Plasma D-Bus 设置桌面壁纸，必要时回退到 XDG Wallpaper Portal。
- 中文 / 英文界面、自定义下载目录和 KDE Wallet API Key 存储。

“收藏排行”按 Wallhaven 的收藏数量排序，不是个人收藏夹同步。

## 快速开始

从仓库页面复制克隆地址，替换 `<REPOSITORY_URL>`：

```sh
git clone --branch feat/kubuntu-plasma-bluecurve <REPOSITORY_URL> wallhaven
cd wallhaven
```

准备 CMake 3.24+、Ninja、C++20 编译器、Qt 6.5+ 开发组件和 KDE Frameworks 6 Wallet，然后在仓库根目录执行：

```sh
cmake -S Linux -B Linux/build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build Linux/build
Linux/build/WallhavenLinux
```

请在图形化 Plasma 会话内运行。完整依赖、安装、Flatpak 打包和排错说明见 **[Linux/README.md](Linux/README.md)**。

## 使用说明

从“最热”“最新”或“收藏排行”进入图库，也可以输入关键词搜索。选中图片后可下载、打开来源页面或设为桌面壁纸；“已下载”用于管理本地图片。设置中可调整语言、下载位置、宽高比匹配及可选 API Key。

默认下载位置是系统图片目录下的 `WallhavenLinux` 文件夹，通常为 `~/Pictures/WallhavenLinux`。普通 SFW 搜索无需 API Key；填写的密钥保存在 KDE Wallet。

Plasma 直接集成会更新当前会话的所有桌面。通过 Portal 设置时，交互和支持范围由桌面门户服务决定。本地下载库的删除操作会直接删除文件。

## 代码入口

| 路径 | 内容 |
| --- | --- |
| `Linux/qml/` | QML 界面与 Bluecurve 风格组件 |
| `Linux/src/` | 搜索、下载、本地库、KWallet 与桌面集成 |
| `Linux/packaging/` | 桌面入口、图标、应用元数据和 Flatpak 清单 |
| `Linux/CMakeLists.txt` | Linux 构建与安装配置 |

本分支保留了 `Sources/` 等 macOS 历史目录；Linux 开发以 `Linux/` 为入口。macOS 当前版本在 `mac` 分支，Windows 版本在 `codex/windows-port` 分支，项目总览见 `main` 分支。

## 许可证

源代码与项目文档采用 [MIT 许可证](LICENSE)。

壁纸内容来自 Wallhaven，图片权利归各自权利人所有。本项目为非官方客户端。 MIT 许可证不授予这些壁纸图片的使用权。
