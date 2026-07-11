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
    title: "Wallhaven Linux — bluecurve Edition"

    WallpaperController {
        id: controller
    }

    property int selectedIndex: controller.wallpapers.length > 0 ? 0 : -1
    property var selectedWallpaper: selectedIndex >= 0 ? controller.wallpapers[selectedIndex] : null

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
        implicitHeight: 30
        implicitWidth: 94
        font.bold: true
        font.pixelSize: 13
        contentItem: Text {
            text: button.text
            font: button.font
            color: button.enabled ? bluecurve.text : "#667078"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        background: Bevel {
            sunken: button.down
            color: button.hovered ? "#dce8f3" : bluecurve.base
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
            width: combo.width
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
            width: combo.width - 4
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
                    text: "KDE Plasma Wayland · bluecurve Edition"
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
                    placeholderText: "搜索壁纸，例如：城市、山脉、赛博朋克"
                    selectByMouse: true
                    font.pixelSize: 13
                    background: Bevel { sunken: true; color: "white" }
                    onAccepted: searchButton.clicked()
                }
                BlueCombo { id: categoryBox; model: ["General", "Anime", "People", "All"] }
                BlueCombo { id: purityBox; model: ["SFW", "SFW + Sketchy"] }
                BlueCombo { id: sortingBox; model: ["Random", "Date Added", "Relevance"] }
                BlueButton {
                    id: searchButton
                    text: controller.searching ? "搜索中…" : "搜索"
                    enabled: !controller.searching
                    onClicked: {
                        const categories = ["general", "anime", "people", "all"]
                        const purity = ["sfw", "sketchy"]
                        const sorting = ["random", "date_added", "relevance"]
                        controller.search(searchField.text, categories[categoryBox.currentIndex], purity[purityBox.currentIndex], sorting[sortingBox.currentIndex])
                    }
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
                    Text { text: "控制面板"; font.bold: true; color: bluecurve.darkBlue; font.pixelSize: 14 }
                    Rectangle { Layout.fillWidth: true; height: 1; color: bluecurve.shadow }
                    Text { text: "桌面集成"; font.bold: true; color: bluecurve.text }
                    RowLayout {
                        Layout.fillWidth: true
                        Rectangle { width: 10; height: 10; radius: 5; color: controller.plasmaAvailable ? "#2f8a38" : "#b0392e" }
                        Text {
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            text: controller.plasmaAvailable ? "Plasma 壁纸服务可用" : "Plasma 服务未检测到"
                            font.pixelSize: 12
                        }
                    }
                    BlueButton { Layout.fillWidth: true; text: "重新检测"; onClicked: controller.refreshDesktopCapability() }
                    Rectangle { Layout.fillWidth: true; height: 1; color: bluecurve.shadow }
                    Text { text: "本地库"; font.bold: true; color: bluecurve.text }
                    Text {
                        Layout.fillWidth: true
                        text: controller.downloadDirectory
                        wrapMode: Text.WrapAnywhere
                        color: "#35495d"
                        font.pixelSize: 11
                    }
                    BlueButton { Layout.fillWidth: true; text: "打开下载目录"; onClicked: controller.openDownloadDirectory() }
                    Item { Layout.fillHeight: true }
                    Text {
                        Layout.fillWidth: true
                        text: "首版会将壁纸应用到当前 Plasma 会话的所有桌面。"
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
                    text: "搜索 Wallhaven，结果会显示在这里"
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
                    Text { text: "预览"; font.bold: true; color: bluecurve.darkBlue; font.pixelSize: 14 }
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
                        text: selectedWallpaper ? "#" + selectedWallpaper.id : "未选择壁纸"
                        color: bluecurve.text
                        font.bold: true
                        font.pixelSize: 15
                    }
                    Text {
                        Layout.fillWidth: true
                        text: selectedWallpaper ? selectedWallpaper.resolution + " · " + selectedWallpaper.category + " · " + selectedWallpaper.purity : "选择一张壁纸以查看详情。"
                        wrapMode: Text.Wrap
                        color: "#384b5f"
                        font.pixelSize: 12
                    }
                    Item { Layout.fillHeight: true }
                    BlueButton {
                        Layout.fillWidth: true
                        text: controller.downloading ? "下载中…" : "下载"
                        enabled: selectedIndex >= 0 && !controller.downloading
                        onClicked: controller.download(selectedIndex)
                    }
                    BlueButton {
                        Layout.fillWidth: true
                        text: "设为桌面壁纸"
                        enabled: selectedIndex >= 0 && !controller.downloading && controller.plasmaAvailable
                        onClicked: controller.setWallpaper(selectedIndex)
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
    }

    Component.onCompleted: controller.search("", "general", "sfw", "random")
}
