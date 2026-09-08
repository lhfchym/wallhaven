# Wallhaven

一个围绕 [wallhaven.cc](https://wallhaven.cc) 开发的桌面壁纸工具，用于浏览、搜索、预览、下载图片，并设置桌面壁纸。

本仓库按平台维护代码。`main` 仅保留项目说明和分支导航；开发、构建和打包请进入对应平台分支。

## 平台分支

| 平台 | 分支 | 代码与构建说明 |
| --- | --- | --- |
| macOS | [`mac`](http://10.0.0.162:8082/lhfchym/wallhaven/src/branch/mac) | 原 macOS 版本，使用 SwiftUI / AppKit；见分支根目录的 [README](http://10.0.0.162:8082/lhfchym/wallhaven/src/branch/mac/README.md)。 |
| Linux / KDE Plasma | [`feat/kubuntu-plasma-bluecurve`](http://10.0.0.162:8082/lhfchym/wallhaven/src/branch/feat/kubuntu-plasma-bluecurve) | Qt 6 / QML 版本；见 [Linux 目录](http://10.0.0.162:8082/lhfchym/wallhaven/src/branch/feat/kubuntu-plasma-bluecurve/Linux)。 |
| Windows | [`codex/windows-port`](http://10.0.0.162:8082/lhfchym/wallhaven/src/branch/codex/windows-port) | Qt 6 / QML 版本，集成 Windows 桌面与凭据接口；见 [Windows 目录](http://10.0.0.162:8082/lhfchym/wallhaven/src/branch/codex/windows-port/Windows)。 |
| Haiku | [`feat/haiku-native-port`](http://10.0.0.162:8082/lhfchym/wallhaven/src/branch/feat/haiku-native-port) | C++ / Haiku 原生版本；见 [Haiku 使用与构建说明](http://10.0.0.162:8082/lhfchym/wallhaven/src/branch/feat/haiku-native-port/Haiku/README.md)。 |

## 获取代码

克隆时指定所需平台分支，例如 macOS：

```sh
git clone --branch mac http://10.0.0.162:8082/lhfchym/wallhaven.git
```

已有本地仓库时，可以获取远端分支并切换：

```sh
git fetch origin
git switch mac
```

其他平台将 `mac` 替换为表中的分支名称。构建依赖、运行命令和安装方式以对应分支内的说明为准。

## 仓库维护

- `main` 用于维护项目介绍、平台入口和通用说明。
- 各平台的功能开发、修复、测试和打包在对应平台分支进行。
- 平台分支可能保留共同基线中的其他平台目录，请以表中指定的目录为入口。
- 本次整理将原 `main` 的完整 macOS 代码及提交历史保留在 `mac` 分支，基线提交为 `f185cf6681a954c7fbdab34b14c60a6261044884`（`v0.2.0`）。原有平台分支和标签保持不变。
