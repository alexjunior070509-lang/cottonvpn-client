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

    // CottonVPN — единственный экран в стиле сайта (сиреневый градиент, акцент-фиолетовый),
    // с явным индикатором ВКЛ/ВЫКЛ.
    property bool hasServer: ServersUiController.defaultServerName !== ""
    property bool editingKey: false
    property bool showKeyField: !hasServer || editingKey

    // палитра лендинга cottonvpn.com
    readonly property string cInk:     "#241C47"
    readonly property string cMuted:   "#6C6790"
    readonly property string cViolet:  "#7C5CFF"
    readonly property string cLine:    "#ECE7F8"
    readonly property string cGreen:   "#10B981"
    readonly property string cCard:    "#FFFFFF"

    readonly property bool isOn: ConnectionController.isConnected
    readonly property bool isBusy: ConnectionController.isConnectionInProgress

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

    // фон-градиент как на сайте
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#FBF8FF" }
            GradientStop { position: 0.55; color: "#F4EEFB" }
            GradientStop { position: 1.0; color: "#FBF6FF" }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 24 + PageController.safeAreaTopMargin
        anchors.bottomMargin: 24 + PageController.safeAreaBottomMargin
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        spacing: 14

        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 8
            text: "CottonVPN"
            color: root.cViolet
            font.family: "PT Root UI VF"
            font.weight: 800
            font.pixelSize: 26
        }

        Item { Layout.fillHeight: true; Layout.fillWidth: true }

        // ===== есть ключ: большая кнопка + явный статус =====
        ConnectButton {
            id: connectButton
            objectName: "connectButton"
            visible: !root.showKeyField
            Layout.alignment: Qt.AlignHCenter

            defaultButtonColor: root.cMuted        // кольцо/глиф когда выключено
            connectedButtonColor: root.cGreen      // кольцо когда включено
            connectedFillColor: root.cGreen        // заливка круга когда включено
            offFillColor: root.cCard               // белый круг когда выключено
            glowColor: root.cViolet
        }

        // индикатор состояния: точка + крупное слово + подпись
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 18
            visible: !root.showKeyField
            spacing: 4

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8

                Rectangle {
                    id: statusDot
                    width: 12; height: 12; radius: 6
                    Layout.alignment: Qt.AlignVCenter
                    color: root.isOn ? root.cGreen : (root.isBusy ? root.cViolet : "#C7C2DE")

                    SequentialAnimation on opacity {
                        running: root.isOn || root.isBusy
                        loops: Animation.Infinite
                        NumberAnimation { from: 1.0; to: 0.3; duration: 900 }
                        NumberAnimation { from: 0.3; to: 1.0; duration: 900 }
                    }
                }

                Text {
                    text: root.isOn ? qsTr("Подключено")
                                    : (root.isBusy ? qsTr("Подключение…") : qsTr("Отключено"))
                    color: root.isOn ? root.cGreen : root.cInk
                    font.family: "PT Root UI VF"
                    font.weight: 800
                    font.pixelSize: 22
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.isOn ? qsTr("Соединение защищено")
                                : (root.isBusy ? qsTr("Устанавливаем соединение") : qsTr("Нажми кнопку, чтобы включить"))
                color: root.cMuted
                font.family: "PT Root UI VF"
                font.pixelSize: 14
            }
        }

        // ===== ключа нет: поле ввода =====
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.showKeyField
            spacing: 16

            Text {
                Layout.fillWidth: true
                text: qsTr("Вставь ключ из бота, чтобы подключиться")
                color: root.cMuted
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

                backgroundColor: root.cCard
                borderColor: root.cLine
                borderFocusedColor: root.cViolet
                bgBorderHoveredColor: root.cViolet
                headerTextColor: root.cMuted
                textFieldTextColor: root.cInk

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
                defaultColor: root.cViolet
                hoveredColor: "#6B4FE6"
                pressedColor: "#5B41D6"
                textColor: root.cCard

                clickedFunc: function() {
                    if (ImportController.extractConfigFromData(textKey.textField.text)) {
                        ImportController.importConfig()
                    }
                }
            }
        }

        Item { Layout.fillHeight: true; Layout.fillWidth: true }

        // ссылка «Сменить ключ» — только когда ключ уже есть
        Text {
            Layout.alignment: Qt.AlignHCenter
            visible: root.hasServer && !root.editingKey
            text: qsTr("Сменить ключ")
            color: root.cViolet
            font.family: "PT Root UI VF"
            font.weight: 700
            font.pixelSize: 15

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.editingKey = true
            }
        }
    }
}
