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

    // CottonVPN: минимальный главный экран — большая кнопка вкл/выкл + поле ввода ключа.
    property bool hasServer: ServersUiController.defaultServerName !== ""

    Connections {
        target: ImportController

        function onImportFinished() {
            textKey.textField.text = ""
            PageController.showNotificationMessage(qsTr("Ключ добавлен"))
        }
        function onImportErrorOccurred(errorCode, goToPageHome) {
            PageController.showNotificationMessage(qsTr("Не удалось добавить ключ — проверь, что вставлен правильно"))
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 24 + PageController.safeAreaTopMargin
        anchors.bottomMargin: 24 + PageController.safeAreaBottomMargin
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 16

        Header1TextType {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 8

            text: "CottonVPN"
            horizontalAlignment: Qt.AlignHCenter
        }

        // верхний растяжитель — центрируем кнопку
        Item { Layout.fillHeight: true; Layout.fillWidth: true }

        ConnectButton {
            id: connectButton
            objectName: "connectButton"

            Layout.alignment: Qt.AlignHCenter
        }

        // нижний растяжитель
        Item { Layout.fillHeight: true; Layout.fillWidth: true }

        // строка ввода ключа
        TextFieldWithHeaderType {
            id: textKey
            objectName: "homeKeyField"

            Layout.fillWidth: true

            headerText: root.hasServer ? qsTr("Сменить ключ") : qsTr("Вставь ключ из бота")
            buttonText: qsTr("Вставить")

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

            clickedFunc: function() {
                if (ImportController.extractConfigFromData(textKey.textField.text)) {
                    ImportController.importConfig()
                }
            }
        }
    }
}
