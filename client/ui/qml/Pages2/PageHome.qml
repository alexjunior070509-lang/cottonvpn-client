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

    // ===== статус подписки с бэкенда (трафик за месяц + остаток дней) =====
    // Идентификатор — pubkey AWG-ключа; заодно репортим свою версию,
    // чтобы бот мог показать «доступно обновление».
    property var subInfo: null

    function refreshSubInfo() {
        if (!root.hasServer) { root.subInfo = null; return }
        var pub = ServersUiController.getDefaultServerAwgClientPubKey()
        if (!pub) { root.subInfo = null; return }
        var url = "https://webhook.cottonvpn.com/app/status?pub=" + encodeURIComponent(pub)
                + "&v=" + encodeURIComponent(SettingsController.getReleaseVersion())
        var xhr = new XMLHttpRequest()
        xhr.open("GET", url)
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status === 200) {
                try { root.subInfo = JSON.parse(xhr.responseText) } catch (e) {}
            }
        }
        xhr.send()
    }

    function daysWord(n) {
        var m10 = n % 10, m100 = n % 100
        if (m10 === 1 && m100 !== 11) return qsTr("день")
        if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return qsTr("дня")
        return qsTr("дней")
    }

    Component.onCompleted: refreshSubInfo()
    onIsOnChanged: refreshSubInfo()
    onHasServerChanged: refreshSubInfo()

    Timer {
        interval: 15 * 60 * 1000
        repeat: true
        running: true
        onTriggered: root.refreshSubInfo()
    }

    Connections {
        target: ImportController
        function onImportFinished() {
            textKey.textField.text = ""
            root.editingKey = false
            PageController.showNotificationMessage(qsTr("Ключ добавлен"))
            root.refreshSubInfo()
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

    // ===== шестерёнка — меню настроек (верхний правый угол) =====
    ImageButtonType {
        visible: !root.showKeyField
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 16 + PageController.safeAreaTopMargin
        anchors.rightMargin: 16
        implicitWidth: 44
        implicitHeight: 44
        image: "qrc:/images/controls/settings.svg"
        imageColor: root.cMuted
        onClicked: settingsDrawer.open()
    }

    // ===== меню настроек (выезжает снизу) =====
    Drawer {
        id: settingsDrawer
        edge: Qt.BottomEdge
        width: root.width
        height: settingsCol.implicitHeight + 44 + PageController.safeAreaBottomMargin

        onOpened: ruSwitch.checked = IpSplitTunnelingController.isRussiaPresetEnabled()

        background: Rectangle {
            color: root.cCard
            radius: 24
            Rectangle { // прямые нижние углы
                color: root.cCard
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 24
            }
        }

        ColumnLayout {
            id: settingsCol
            anchors { left: parent.left; right: parent.right; top: parent.top }
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            anchors.topMargin: 20
            spacing: 12

            Rectangle { // «ручка» шторки
                Layout.alignment: Qt.AlignHCenter
                width: 36; height: 4; radius: 2
                color: root.cLine
            }

            Text {
                text: qsTr("Настройки")
                color: root.cInk
                font.family: "PT Root UI VF"
                font.weight: 800
                font.pixelSize: 20
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 4
                radius: 16
                color: root.cCard
                border.color: root.cLine
                border.width: 1
                implicitHeight: ruRow.implicitHeight + 24

                RowLayout {
                    id: ruRow
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 12
                    anchors.topMargin: 12
                    anchors.bottomMargin: 12
                    spacing: 8

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: qsTr("🇷🇺 Российские сервисы напрямую")
                            color: root.cInk
                            font.family: "PT Root UI VF"
                            font.weight: 600
                            font.pixelSize: 15
                        }
                        Text {
                            text: qsTr("Банки, Госуслуги и т.п. в обход VPN")
                            color: root.cMuted
                            font.family: "PT Root UI VF"
                            font.pixelSize: 12
                        }
                    }

                    Switch {
                        id: ruSwitch
                        checked: IpSplitTunnelingController.isRussiaPresetEnabled()
                        onToggled: {
                            if (checked) {
                                IpSplitTunnelingController.enableRussiaPreset()
                            } else {
                                IpSplitTunnelingController.disableRussiaPreset()
                            }
                            if (ConnectionController.isConnected) {
                                PageController.showNotificationMessage(qsTr("Изменение применится после переподключения VPN"))
                            }
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("Применяется при следующем подключении VPN")
                color: root.cMuted
                font.family: "PT Root UI VF"
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 24 + PageController.safeAreaTopMargin
        anchors.bottomMargin: 24 + PageController.safeAreaBottomMargin
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        spacing: 14

        RowLayout {
            Layout.alignment: Qt.AlignLeft
            spacing: 10

            Image {
                source: "qrc:/images/cotton-logo.svg"
                // sourceSize крупнее целевого размера: SVG растрируется в 128px и
                // сглаженно уменьшается — без мыла на экранах любой плотности
                sourceSize.width: 128
                sourceSize.height: 128
                Layout.preferredWidth: 40
                Layout.preferredHeight: 34
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
            }

            Text {
                text: "CottonVPN"
                color: root.cViolet
                font.family: "PT Root UI VF"
                font.weight: 800
                font.pixelSize: 26
            }
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

        // ===== карточка подписки: трафик за месяц + остаток дней =====
        Rectangle {
            id: subCard
            visible: !root.showKeyField && root.subInfo !== null
            Layout.fillWidth: true
            Layout.topMargin: 18
            radius: 16
            color: root.cCard
            border.color: root.cLine
            border.width: 1
            implicitHeight: subCol.implicitHeight + 28

            readonly property real usedGb: root.subInfo ? root.subInfo.traffic_used / 1073741824 : 0
            readonly property int limitGb: root.subInfo ? Math.round(root.subInfo.traffic_limit / 1073741824) : 0
            readonly property real usedFrac: (root.subInfo && root.subInfo.traffic_limit > 0)
                                             ? Math.min(1, root.subInfo.traffic_used / root.subInfo.traffic_limit) : 0
            readonly property bool blocked: root.subInfo ? root.subInfo.traffic_blocked === true : false
            readonly property int daysLeft: root.subInfo ? root.subInfo.days_left : 0

            ColumnLayout {
                id: subCol
                anchors { left: parent.left; right: parent.right; top: parent.top }
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.topMargin: 14
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: qsTr("Трафик за месяц")
                        color: root.cMuted
                        font.family: "PT Root UI VF"
                        font.pixelSize: 13
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: subCard.limitGb > 0
                              ? qsTr("%1 из %2 ГБ").arg(subCard.usedGb.toFixed(1)).arg(subCard.limitGb)
                              : qsTr("%1 ГБ").arg(subCard.usedGb.toFixed(1))
                        color: root.cInk
                        font.family: "PT Root UI VF"
                        font.weight: 700
                        font.pixelSize: 13
                    }
                }

                Rectangle { // прогресс-бар лимита
                    Layout.fillWidth: true
                    height: 6
                    radius: 3
                    color: root.cLine
                    visible: subCard.limitGb > 0

                    Rectangle {
                        width: parent.width * subCard.usedFrac
                        height: parent.height
                        radius: 3
                        color: subCard.blocked ? "#E5484D"
                             : (subCard.usedFrac > 0.9 ? "#F59E0B" : root.cViolet)
                    }
                }

                Text {
                    visible: subCard.blocked
                    Layout.fillWidth: true
                    text: qsTr("Лимит исчерпан — доступ вернётся с 1 числа")
                    color: "#E5484D"
                    font.family: "PT Root UI VF"
                    font.weight: 600
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: qsTr("Подписка")
                        color: root.cMuted
                        font.family: "PT Root UI VF"
                        font.pixelSize: 13
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        readonly property bool active: root.subInfo ? root.subInfo.active === true : false
                        readonly property int d: subCard.daysLeft
                        text: active ? qsTr("осталось %1 %2").arg(d).arg(root.daysWord(d))
                                     : qsTr("не активна")
                        color: active ? root.cInk : "#E5484D"
                        font.family: "PT Root UI VF"
                        font.weight: 700
                        font.pixelSize: 13
                    }
                }
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

            // «Назад» — только если ключ уже есть и мы вошли в режим смены
            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 2
                visible: root.hasServer && root.editingKey
                text: qsTr("◀ Назад")
                color: root.cMuted
                font.family: "PT Root UI VF"
                font.weight: 600
                font.pixelSize: 15

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        textKey.textField.text = ""
                        root.editingKey = false
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

        // версия приложения
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 4
            text: SettingsController.getAppVersion()
            color: root.cMuted
            font.family: "PT Root UI VF"
            font.pixelSize: 12
            opacity: 0.7
        }
    }
}
