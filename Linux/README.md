# Linux 构建与使用

[返回分支首页](../README.md)

Linux 客户端使用 Qt 6 / QML 和 C++20，目标环境为 Kubuntu 26.04 LTS、KDE Plasma 与 Wayland。应用名称为 **WallhavenLinux**，独立开发分支为 `feat/kubuntu-plasma-bluecurve`。

以下构建与打包命令均在仓库根目录执行。

## 依赖

| 依赖 | 要求 |
| --- | --- |
| 编译器 | 支持 C++20 |
| CMake | 3.24+ |
| Ninja | 用于下方的 CMake 构建命令 |
| Qt | 6.5+，Core、Gui、Network、Qml、Quick、QuickControls2、DBus 开发组件 |
| KDE Frameworks | KF6 Wallet 开发组件，提供 `KF6Wallet` |
| 图形会话 | KDE Plasma、会话 D-Bus |
| 目录选择器 | `kdialog` |
| Portal 回退 | 提供 Wallpaper 接口的 XDG Desktop Portal 服务及桌面后端 |

安装开发包时，请使用发行版提供的相应软件包。Bluecurve 图标主题是可选的；应用会尝试使用活动主题中的操作图标。

## 构建与运行

```sh
cmake -S Linux -B Linux/build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build Linux/build
Linux/build/WallhavenLinux
```

二进制位于 `Linux/build/WallhavenLinux`。请在图形化 Plasma 会话中启动，以访问当前会话的 D-Bus、KDE Wallet 和桌面服务。

如果 Qt 安装在自定义位置，可在首次配置时通过 `-DCMAKE_PREFIX_PATH=/path/to/Qt` 指定前缀。该路径为占位示例，需要替换为实际安装目录。

### 安装到用户目录

```sh
cmake --install Linux/build --prefix "$HOME/.local"
"$HOME/.local/bin/WallhavenLinux"
```

安装内容包括可执行文件、桌面入口、图标及应用元数据。应用菜单是否立即出现新入口取决于桌面环境的缓存刷新。

## Flatpak

仓库提供 [Flatpak 清单](packaging/dev.local.WallhavenLinux.yml)，应用 ID 为 `dev.local.WallhavenLinux`。清单使用 KDE 6.10 Platform 与 SDK。

准备 Flatpak、flatpak-builder，并安装对应版本的 KDE Platform 与 SDK 后执行：

```sh
flatpak-builder --user --install --force-clean build-flatpak Linux/packaging/dev.local.WallhavenLinux.yml
flatpak run dev.local.WallhavenLinux
```

`--force-clean` 会重建指定的 `build-flatpak` 构建目录。

Flatpak 清单允许联网、Wayland / 回退 X11、KDE Wallet 访问和系统图片目录访问。沙箱中的壁纸设置通过 XDG Wallpaper Portal 请求；是否显示预览或确认界面由桌面后端决定。自定义下载目录需要位于沙箱可写的范围内。

## 日常使用

- 通过关键词、分类、内容分级和排序筛选壁纸；分辨率筛选依据当前检测到的显示器，可选严格宽高比匹配。
- “最热”“最新”“收藏排行”提供快捷排序；“收藏排行”不是个人收藏夹。
- 选择图片后可预览、下载原图、打开来源页面或设置桌面壁纸。
- 滚动接近图库底部会加载下一页，并保留当前浏览位置和选择。
- “已下载”支持打开下载目录、重新应用壁纸和删除本地文件；删除操作直接移除文件。
- 设置支持中英文切换、下载目录、宽高比匹配和可选 API Key。

普通 SFW 搜索无需 API Key。需要受限内容筛选时填写自己的 Wallhaven API Key；应用会异步读写 KDE Wallet，首次访问时可能出现钱包解锁提示。

## 桌面集成与数据

| 项目 | 行为 |
| --- | --- |
| 壁纸设置 | 优先调用 Plasma 会话 D-Bus，更新当前会话所有桌面 |
| 回退方式 | 直接调用失败或不可用时使用 XDG Wallpaper Portal，并等待桌面服务返回结果 |
| 下载位置 | 系统图片目录下的 `WallhavenLinux`，通常为 `~/Pictures/WallhavenLinux` |
| 偏好设置 | Qt `QSettings` |
| API Key | KDE Wallet |

## 常见问题

**CMake 找不到 Qt 或 KF6Wallet**

确认安装了开发组件，而不只是运行时库。Qt 需包含 QML、Quick Controls 2 和 DBus；KDE Wallet 需要 KF6 版本。自定义安装位置可通过 CMake 前缀路径指定。

**能浏览图片，但无法设置壁纸**

确认应用运行在 Plasma 图形会话内，并能访问该会话的 D-Bus。使用 Flatpak 时，检查 XDG Desktop Portal 和对应桌面后端是否提供 Wallpaper 接口。

**API Key 没有保存或重启后不可用**

确认 KDE Wallet 服务可用，并已完成钱包解锁或应用访问授权。

**下载目录选择器无法打开**

原生构建会调用 `kdialog`。确认它已安装且可在当前会话中执行；Flatpak 还需考虑沙箱可访问的程序与目录范围。

## 源码

- [CMakeLists.txt](CMakeLists.txt)：依赖、构建目标与安装规则。
- [qml/Main.qml](qml/Main.qml)：界面与交互。
- [src/WallpaperController.cpp](src/WallpaperController.cpp)：搜索、下载、本地库及系统集成。
- [packaging/](packaging/)：Flatpak 清单、桌面入口和图标。

## 许可证

源代码与项目文档采用 [MIT 许可证](../LICENSE)。壁纸图片的权利归各自权利人所有。
