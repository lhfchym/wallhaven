import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Wallhaven

ApplicationWindow {
    id: window
    width: 1380
    height: 860
    minimumWidth: 1060
    minimumHeight: 660
    visible: true
    title: window.t("Wallhaven Linux — 蓝色曲线版", "Wallhaven Linux — Bluecurve Edition")

    WallpaperController {
        id: controller
    }

    property int selectedIndex: controller.wallpapers.length > 0 ? 0 : -1
    property var selectedWallpaper: selectedIndex >= 0 ? controller.wallpapers[selectedIndex] : null
    property bool preserveGridPositionForAppend: false
    property real gridPositionBeforeAppend: 0
    onVisibleChanged: if (visible) controller.refreshDesktopCapability()

    function t(chinese, english) {
        return controller.language === "en" ? english : chinese
    }

    function submitCurrentSearch() {
        preserveGridPositionForAppend = false
        const categories = ["general", "anime", "people", "all"]
        const purity = ["sfw", "sketchy", "all"]
        const sorting = ["toplist", "date_added", "favorites", "random", "views", "relevance"]
        controller.search(searchField.text, categories[categoryBox.currentIndex], purity[purityBox.currentIndex], sorting[sortingBox.currentIndex])
    }

    function loadNextPagePreservingPosition() {
        if (!controller.canLoadMore || controller.searching) return
        gridPositionBeforeAppend = wallpaperGrid.contentY
        preserveGridPositionForAppend = true
        controller.loadNextPage()
    }

    color: bluecurve.base

    QtObject {
        id: bluecurve
        readonly property color base: "#d4d0c8"
        readonly property color shadow: "#53677a"
        readonly property color highlight: "#ffffff"
        readonly property color mid: "#9bb3ca"
        readonly property color blue: "#245a99"
        readonly property color darkBlue: "#123c70"
        readonly property color selection: "#2e66a2"
        readonly property color text: "#101820"
    }

    component Bevel: Rectangle {
        property bool sunken: false
        color: bluecurve.base
        border.width: 1
        border.color: sunken ? bluecurve.shadow : bluecurve.highlight
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            color: "transparent"
            border.width: 1
            border.color: sunken ? bluecurve.highlight : bluecurve.shadow
        }
    }

    component BlueButton: Button {
        id: button
        property bool selected: false
        property string themeIcon: ""
        implicitHeight: 30
        implicitWidth: 94
        font.bold: true
        font.pixelSize: 13
        icon.name: button.themeIcon
        icon.width: 16
        icon.height: 16
        display: button.themeIcon.length > 0 ? AbstractButton.TextBesideIcon : AbstractButton.TextOnly
        leftPadding: 7
        rightPadding: 7
        background: Bevel {
            sunken: button.down
            color: button.selected ? "#9cc8ee" : (button.hovered ? "#dce8f3" : bluecurve.base)
            opacity: button.enabled ? 1 : 0.65
        }
    }

    component BlueCombo: ComboBox {
        id: combo
        implicitHeight: 30
        font.pixelSize: 13
        contentItem: Text {
            leftPadding: 8
            rightPadding: 26
            text: combo.displayText
            color: bluecurve.text
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        background: Bevel { sunken: combo.pressed }
        indicator: Text {
            x: combo.width - width - 8
            y: combo.topPadding + (combo.availableHeight - height) / 2
            text: "▼"
            color: bluecurve.darkBlue
            font.pixelSize: 10
        }
        popup: Popup {
            y: combo.height - 1
            width: Math.max(combo.width, 184)
            implicitHeight: contentItem.implicitHeight
            padding: 2
            contentItem: ListView {
                clip: true
                implicitHeight: contentHeight
                model: combo.popup.visible ? combo.delegateModel : null
                currentIndex: combo.highlightedIndex
            }
            background: Bevel { sunken: true }
        }
        delegate: ItemDelegate {
            width: combo.popup.width - 4
            height: 28
            contentItem: Text {
                text: modelData
                color: highlighted ? "white" : bluecurve.text
                verticalAlignment: Text.AlignVCenter
                leftPadding: 6
            }
            background: Rectangle { color: highlighted ? bluecurve.selection : "transparent" }
        }
    }

    header: Rectangle {
        height: 68
        gradient: Gradient {
            GradientStop { position: 0; color: "#4e91d0" }
            GradientStop { position: 0.45; color: bluecurve.blue }
            GradientStop { position: 1; color: bluecurve.darkBlue }
        }
        border.width: 1
        border.color: "#0e315d"
        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 12
            Rectangle {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                color: "#d7e9fb"
                border.width: 2
                border.color: "#0a315f"
                Text {
                    anchors.centerIn: parent
                    text: "W"
                    color: bluecurve.darkBlue
                    font.bold: true
                    font.pixelSize: 27
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    text: "WALLHAVEN LINUX"
                    color: "white"
                    font.bold: true
                    font.pixelSize: 21
                    style: Text.Raised
                    styleColor: "#12365f"
                }
                Text {
                    text: "KDE Plasma Wayland · " + window.t("蓝色曲线版", "Bluecurve Edition")
                    color: "#dcecff"
                    font.pixelSize: 12
                }
            }
            Text {
                text: controller.displayResolution
                color: "white"
                font.bold: true
                font.pixelSize: 13
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        Bevel {
            Layout.fillWidth: true
            implicitHeight: 72
            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8
                TextField {
                    id: searchField
                    Layout.fillWidth: true
                    implicitHeight: 30
                    placeholderText: window.t("搜索壁纸，例如：城市、山脉、赛博朋克", "Search wallpapers, e.g. city, mountains, cyberpunk")
                    selectByMouse: true
                    font.pixelSize: 13
                    background: Bevel { sunken: true; color: "white" }
                    onAccepted: searchButton.clicked()
                }
                BlueCombo {
                    id: categoryBox
                    model: [window.t("普通", "General"), window.t("动漫", "Anime"), window.t("人物", "People"), window.t("全部", "All")]
                    onActivated: window.submitCurrentSearch()
                }
                BlueCombo {
                    id: purityBox
                    model: controller.apiKey.length > 0
                        ? ["SFW", window.t("安全 + 擦边", "SFW + Sketchy"), window.t("全部（含 NSFW）", "All (including NSFW)")]
                        : ["SFW", window.t("安全 + 擦边", "SFW + Sketchy")]
                    onActivated: window.submitCurrentSearch()
                }
                BlueCombo {
                    id: sortingBox
                    model: [window.t("热门", "Toplist"), window.t("最新", "Latest"), window.t("收藏排行", "Favorites"), window.t("随机", "Random"), window.t("浏览量", "Views"), window.t("相关性", "Relevance")]
                    onActivated: window.submitCurrentSearch()
                }
                BlueButton {
                    id: searchButton
                    themeIcon: "stock-find"
                    text: controller.searching ? window.t("搜索中…", "Searching…") : window.t("搜索", "Search")
                    enabled: !controller.searching
                    onClicked: window.submitCurrentSearch()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            Bevel {
                Layout.preferredWidth: 242
                Layout.fillHeight: true
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 9
                    spacing: 8
                    Text { text: window.t("浏览", "Browse"); font.bold: true; color: bluecurve.darkBlue; font.pixelSize: 14 }
                    Rectangle { Layout.fillWidth: true; height: 1; color: bluecurve.shadow }
                    BlueButton { Layout.fillWidth: true; themeIcon: "stock-goto-top"; text: window.t("热门", "Toplist"); onClicked: { sortingBox.currentIndex = 0; window.submitCurrentSearch() } }
                    BlueButton { Layout.fillWidth: true; themeIcon: "stock-history"; text: window.t("最新", "Latest"); onClicked: { sortingBox.currentIndex = 1; window.submitCurrentSearch() } }
                    BlueButton { Layout.fillWidth: true; themeIcon: "stock-bookmarks"; text: window.t("收藏排行", "Favorites"); onClicked: { sortingBox.currentIndex = 2; window.submitCurrentSearch() } }
                    BlueButton { Layout.fillWidth: true; themeIcon: "folder-downloads"; text: window.t("已下载", "Downloaded"); onClicked: controller.showSection("downloaded") }
                    Rectangle { Layout.fillWidth: true; height: 1; color: bluecurve.shadow }
                    Text { text: window.t("桌面集成", "Desktop Integration"); font.bold: true; color: bluecurve.text }
                    RowLayout {
                        Layout.fillWidth: true
                        Rectangle { width: 10; height: 10; radius: 5; color: controller.plasmaAvailable ? "#2f8a38" : "#b0392e" }
                        Text { Layout.fillWidth: true; wrapMode: Text.Wrap; text: controller.plasmaAvailable ? window.t("Plasma 壁纸服务可用", "Plasma wallpaper service is ready") : window.t("Plasma 服务未检测到", "Plasma service was not detected"); font.pixelSize: 12 }
                    }
                    BlueButton { Layout.fillWidth: true; themeIcon: "stock-refresh"; text: window.t("重新检测", "Recheck"); onClicked: controller.refreshDesktopCapability() }
                    Rectangle { Layout.fillWidth: true; height: 1; color: bluecurve.shadow }
                    Text { text: window.t("下载库", "Library"); font.bold: true; color: bluecurve.text }
                    Text {
                        Layout.fillWidth: true
                        text: controller.downloadDirectory
                        wrapMode: Text.WrapAnywhere
                        color: "#35495d"
                        font.pixelSize: 11
                    }
                    BlueButton { Layout.fillWidth: true; themeIcon: "folder"; text: window.t("打开下载目录", "Open download folder"); onClicked: controller.openDownloadDirectory() }
                    BlueButton {
                        Layout.fillWidth: true
                        themeIcon: "stock-preferences"
                        text: window.t("设置", "Settings")
                        onClicked: {
                            apiKeyField.text = controller.apiKey
                            strictRatioCheck.checked = controller.strictAspectRatio
                            settingsPopup.pendingLanguage = controller.language
                            settingsPopup.open()
                        }
                    }
                    Item { Layout.fillHeight: true }
                    Text {
                        Layout.fillWidth: true
                        text: controller.section === "downloaded" ? window.t("使用下方删除按钮管理本地壁纸。", "Use the Delete button below to manage local wallpapers.") : window.t("当前会将壁纸应用到 Plasma 会话的所有桌面。", "Wallpaper changes apply to all desktops in this Plasma session.")
                        wrapMode: Text.Wrap
                        color: "#4d5964"
                        font.pixelSize: 11
                    }
                }
            }

            Bevel {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#bfc9d3"
                GridView {
                    id: wallpaperGrid
                    anchors.fill: parent
                    anchors.margins: 7
                    clip: true
                    cellWidth: 188
                    cellHeight: 152
                    model: controller.wallpapers
                    onContentYChanged: {
                        if (controller.section === "online" && contentY + height >= contentHeight - cellHeight * 1.5) {
                            window.loadNextPagePreservingPosition()
                        }
                    }
                    delegate: Item {
                        required property var modelData
                        required property int index
                        width: wallpaperGrid.cellWidth
                        height: wallpaperGrid.cellHeight
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 4
                            color: "#f5f5f2"
                            border.width: index === selectedIndex ? 3 : 2
                            border.color: index === selectedIndex ? bluecurve.selection : bluecurve.shadow
                            Image {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 3
                                height: 106
                                source: modelData.thumbnail
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                            }
                            Text {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: 5
                                text: "#" + modelData.id + "  " + modelData.resolution
                                color: bluecurve.text
                                font.pixelSize: 11
                                elide: Text.ElideRight
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: selectedIndex = index
                            }
                        }
                    }
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                }
                Text {
                    anchors.centerIn: parent
                    visible: !controller.searching && controller.wallpapers.length === 0
                    text: controller.section === "downloaded" ? window.t("下载库为空", "The download library is empty") : window.t("搜索 Wallhaven，结果会显示在这里", "Search Wallhaven to see wallpapers here")
                    color: "#455768"
                    font.pixelSize: 15
                }
                BusyIndicator { anchors.centerIn: parent; running: controller.searching; visible: running }
            }

            Bevel {
                Layout.preferredWidth: 318
                Layout.fillHeight: true
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 9
                    spacing: 8
                    Text { text: controller.section === "downloaded" ? window.t("下载壁纸预览", "Downloaded wallpaper preview") : window.t("显示器结构预览", "Display preview"); font.bold: true; color: bluecurve.darkBlue; font.pixelSize: 14 }
                    Rectangle { Layout.fillWidth: true; height: 1; color: bluecurve.shadow }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 210
                        color: "#202b36"
                        border.width: 2
                        border.color: bluecurve.shadow
                        Image {
                            anchors.fill: parent
                            anchors.margins: 3
                            source: selectedWallpaper ? selectedWallpaper.thumbnail : ""
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: selectedWallpaper ? "#" + selectedWallpaper.id : window.t("未选择壁纸", "No wallpaper selected")
                        color: bluecurve.text
                        font.bold: true
                        font.pixelSize: 15
                    }
                    Text {
                        Layout.fillWidth: true
                        text: selectedWallpaper ? selectedWallpaper.resolution + " · " + selectedWallpaper.category + " · " + selectedWallpaper.purity : window.t("选择一张壁纸以查看详情。", "Select a wallpaper to view its details.")
                        wrapMode: Text.Wrap
                        color: "#384b5f"
                        font.pixelSize: 12
                    }
                    Item { Layout.fillHeight: true }
                    BlueButton {
                        Layout.fillWidth: true
                        themeIcon: controller.section === "downloaded" ? "folder" : "stock-download"
                        text: controller.section === "downloaded" ? window.t("在文件管理器中打开", "Open in file manager") : (controller.downloading ? window.t("下载中…", "Downloading…") : window.t("下载", "Download"))
                        enabled: selectedIndex >= 0 && !controller.downloading
                        onClicked: controller.section === "downloaded" ? controller.openDownloadDirectory() : controller.download(selectedIndex)
                    }
                    BlueButton {
                        Layout.fillWidth: true
                        themeIcon: "icon-background-picture"
                        text: window.t("设为桌面壁纸", "Set as wallpaper")
                        enabled: selectedIndex >= 0 && !controller.downloading && controller.plasmaAvailable
                        onClicked: controller.setWallpaper(selectedIndex)
                    }
                    BlueButton {
                        Layout.fillWidth: true
                        themeIcon: controller.section === "downloaded" ? "stock-delete" : "stock-open"
                        text: controller.section === "downloaded" ? window.t("删除此壁纸", "Delete wallpaper") : window.t("打开页面", "Open page")
                        enabled: selectedIndex >= 0 && !controller.downloading
                        onClicked: controller.section === "downloaded" ? controller.deleteDownloaded(selectedIndex) : controller.openPage(selectedIndex)
                    }
                }
            }
        }

        Bevel {
            Layout.fillWidth: true
            implicitHeight: statusText.implicitHeight + 12
            color: controller.errorMessage.length > 0 ? "#f5d2ce" : "#dce8d8"
            Text {
                id: statusText
                anchors.fill: parent
                anchors.margins: 6
                text: controller.errorMessage.length > 0 ? controller.errorMessage : controller.statusMessage
                color: controller.errorMessage.length > 0 ? "#8b1a12" : "#174c21"
                wrapMode: Text.Wrap
                font.pixelSize: 12
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
                Layout.fillWidth: true
                text: controller.section === "downloaded" ? window.t("下载库", "Download library") : window.t("在线图库", "Online gallery")
                color: bluecurve.darkBlue
                font.bold: true
            }
            BlueButton { themeIcon: "stock-refresh"; text: window.t("刷新", "Refresh"); enabled: !controller.searching; onClicked: controller.refresh() }
            BlueButton {
                themeIcon: "stock-go-forward"
                text: window.t("下一页", "Next page")
                visible: controller.section === "online"
                enabled: controller.canLoadMore && !controller.searching
                onClicked: window.loadNextPagePreservingPosition()
            }
        }
    }

    Connections {
        target: controller
        function onWallpapersChanged() {
            if (!window.preserveGridPositionForAppend) {
                selectedIndex = controller.wallpapers.length > 0 ? 0 : -1
            }
        }
        function onPageAppendFinished(success) {
            if (!window.preserveGridPositionForAppend) return
            if (success) {
                Qt.callLater(function() {
                    const maximumY = Math.max(0, wallpaperGrid.contentHeight - wallpaperGrid.height)
                    wallpaperGrid.contentY = Math.min(window.gridPositionBeforeAppend, maximumY)
                    window.preserveGridPositionForAppend = false
                })
            } else {
                window.preserveGridPositionForAppend = false
            }
        }
    }

    Popup {
        id: settingsPopup
        property string pendingLanguage: controller.language
        anchors.centerIn: Overlay.overlay
        modal: true
        focus: true
        width: 480
        padding: 0
        background: Bevel { color: bluecurve.base }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 9
            Text { text: window.t("设置", "Settings"); color: bluecurve.darkBlue; font.bold: true; font.pixelSize: 18 }
            Rectangle { Layout.fillWidth: true; height: 1; color: bluecurve.shadow }
            Text { text: window.t("语言", "Language"); color: bluecurve.text; font.bold: true }
            RowLayout {
                spacing: 6
                BlueButton {
                    text: "中文"
                    selected: settingsPopup.pendingLanguage === "zh-Hans"
                    onClicked: settingsPopup.pendingLanguage = "zh-Hans"
                }
                BlueButton {
                    text: "English"
                    selected: settingsPopup.pendingLanguage === "en"
                    onClicked: settingsPopup.pendingLanguage = "en"
                }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: bluecurve.shadow }
            Text { text: "Wallhaven API Key"; color: bluecurve.text; font.bold: true }
            TextField {
                id: apiKeyField
                Layout.fillWidth: true
                echoMode: TextInput.Password
                placeholderText: window.t("可选：NSFW 与账户相关筛选需要 API Key", "Optional: required for NSFW and account-specific results")
                background: Bevel { sunken: true; color: "white" }
            }
            Text { text: window.t("下载目录", "Download folder"); color: bluecurve.text; font.bold: true }
            Text { Layout.fillWidth: true; text: controller.downloadDirectory; wrapMode: Text.WrapAnywhere; font.pixelSize: 11; color: "#35495d" }
            BlueButton { themeIcon: "folder"; text: window.t("选择目录…", "Choose folder…"); onClicked: controller.chooseDownloadDirectory() }
            CheckBox {
                id: strictRatioCheck
                text: window.t("只显示与当前显示器相同宽高比的壁纸", "Only show wallpapers matching this display's aspect ratio")
                font.pixelSize: 12
            }
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                BlueButton { themeIcon: "stock-cancel"; text: window.t("取消", "Cancel"); onClicked: settingsPopup.close() }
                BlueButton {
                    themeIcon: "stock-save"
                    text: window.t("保存", "Save")
                    onClicked: {
                        controller.setApiKey(apiKeyField.text)
                        controller.setStrictAspectRatio(strictRatioCheck.checked)
                        controller.setLanguage(settingsPopup.pendingLanguage)
                        settingsPopup.close()
                        controller.refresh()
                    }
                }
            }
        }
    }

    Component.onCompleted: controller.refresh()
}
