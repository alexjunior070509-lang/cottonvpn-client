import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import PageEnum 1.0
import Style 1.0

import "./"
import "../Controls2"
import "../Controls2/TextTypes"
import "../Components"

PageType {
    id: root

    // CottonVPN — единственный экран в фирменном стиле "cotton".
    // Первый вход: только поле для ввода ключа.
    // После ввода ключа: только большая кнопка вкл/выкл. Никаких вкладок.
    property bool hasServer: ServersUiController.defaultServerName !== ""
    property bool editingKey: false
    property bool showKeyField: !hasServer || editingKey

    // фирменная cotton-палитра
    readonly property string cottonPage:     "#FAFAF7"
    readonly property string cottonCard:      "#FFFFFF"
    readonly property string cottonInk:       "#0F172A"
    readonly property string cottonMuted:     "#64748B"
    readonly property string cottonLine:      "#E7E5DE"
    readonly property string cottonAccent:    "#14B8A6"
    readonly property string cottonAccentHov: "#0F9E8E"
    readonly property string cottonAccentInk: "#0F766E"

    Connections {
        target: ImportController

        function onImportFinished() {
            textKey.textField.text = ""
            root.editingKey = false
            PageController.showNotificationMessage(qsTr("Ключ добавлен"))
        }
        function onImportErrorOccurred(errorCode, goToPageHome) {
            PageController.showNotificationMessage(qsTr("Не удалось добавить ключ — проверь, что вставлен правильно"))
        }
    }

    // cotton-фон поверх дефолтной тёмной темы
    Rectangle {
        anchors.fill: parent
        color: root.cottonPage
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 24 + PageController.safeAreaTopMargin
        anchors.bottomMargin: 24 + PageController.safeAreaBottomMargin
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        spacing: 16

        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 8

            text: "CottonVPN"
            color: root.cottonInk
            font.family: "PT Root UI VF"
            font.weight: 700
            font.pixelSize: 28
            horizontalAlignment: Text.AlignHCenter
        }

        // верхний растяжитель — центрируем содержимое
        Item { Layout.fillHeight: true; Layout.fillWidth: true }

        // === состояние "ключ есть": только большая кнопка вкл/выкл ===
        ConnectButton {
            id: connectButton
            objectName: "connectButton"

            visible: !root.showKeyField

            Layout.alignment: Qt.AlignHCenter

            defaultButtonColor: root.cottonAccent
            progressButtonColor: root.cottonAccent
            connectedButtonColor: root.cottonAccentInk
        }

        // === состояние "ключа нет": поле ввода ключа ===
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.showKeyField
            spacing: 16

            Text {
                Layout.fillWidth: true
                Layout.bottomMargin: 4

                text: qsTr("Вставь ключ из бота, чтобы подключиться")
                color: root.cottonMuted
                font.family: "PT Root UI VF"
                font.pixelSize: 16
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }

            TextFieldWithHeaderType {
                id: textKey
                objectName: "homeKeyField"

                Layout.fillWidth: true

                headerText: qsTr("Ключ")
                buttonText: qsTr("Вставить")

                backgroundColor: root.cottonCard
                borderColor: root.cottonLine
                borderFocusedColor: root.cottonAccent
                bgBorderHoveredColor: root.cottonAccent
                headerTextColor: root.cottonMuted
                textFieldTextColor: root.cottonInk

                clickedFunc: function() {
                    textField.text = ""
                    textField.paste()
                }
            }

            BasicButtonType {
                id: applyKeyButton
                objectName: "homeApplyKeyButton"

                Layout.fillWidth: true

                visible: textKey.textField.text !== ""

                text: qsTr("Подключить ключ")

                defaultColor: root.cottonAccent
                hoveredColor: root.cottonAccentHov
                pressedColor: root.cottonAccentInk
                textColor: root.cottonCard

                clickedFunc: function() {
                    if (ImportController.extractConfigFromData(textKey.textField.text)) {
                        ImportController.importConfig()
                    }
                }
            }
        }

        // нижний растяжитель
        Item { Layout.fillHeight: true; Layout.fillWidth: true }

        // ссылка "Сменить ключ" — показывается только когда ключ уже есть
        Text {
            Layout.alignment: Qt.AlignHCenter
            visible: root.hasServer && !root.editingKey

            text: qsTr("Сменить ключ")
            color: root.cottonAccentInk
            font.family: "PT Root UI VF"
            font.weight: 600
            font.pixelSize: 15

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.editingKey = true
            }
        }
    }
}
