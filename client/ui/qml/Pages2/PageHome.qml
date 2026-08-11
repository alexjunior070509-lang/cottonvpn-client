import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore

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

    // ===== тема =====
    // "auto" — как в системе; тумблер в шторке настроек переключает на явные dark/light
    Settings {
        id: themeSettings
        category: "cotton"
        property string theme: "auto"
    }

    // Последний известный статус подписки. Держим на диске, чтобы карточка была на экране
    // ВСЕГДА (просьба владельца 2026-08-11), а не только когда свежий запрос успел пройти:
    // при выключенном VPN или в «плохом окне» сети запрос может не дойти, и раньше карточка
    // просто исчезала. Показываем последнее известное, пока не приедет новое.
    Settings {
        id: subCache
        category: "cotton"
        property string lastStatus: ""
    }
    // Qt::ColorScheme::Dark == 2 — числом, чтобы не зависеть от регистрации scoped-enum в QML
    readonly property bool systemDark: Application.styleHints.colorScheme === 2
    readonly property bool darkMode: themeSettings.theme === "auto" ? systemDark
                                                                    : themeSettings.theme === "dark"

    // палитра лендинга cottonvpn.com (+ тёмный вариант в тех же тонах)
    readonly property string cInk:     darkMode ? "#F1EDFF" : "#241C47"
    readonly property string cMuted:   darkMode ? "#9D97C2" : "#6C6790"
    readonly property string cViolet:  darkMode ? "#9B82FF" : "#7C5CFF"
    readonly property string cLine:    darkMode ? "#332B58" : "#ECE7F8"
    readonly property string cGreen:   darkMode ? "#34D399" : "#10B981"
    readonly property string cCard:    darkMode ? "#231D42" : "#FFFFFF"

    readonly property bool isOn: ConnectionController.isConnected
    readonly property bool isBusy: ConnectionController.isConnectionInProgress

    // ===== статус подписки с бэкенда (трафик за месяц + остаток дней) =====
    // Идентификатор — pubkey AWG-ключа; заодно репортим свою версию,
    // чтобы бот мог показать «доступно обновление».
    property var subInfo: null
    // подписки под этим ключом на сервере нет (ответ 404) — не путать с «сеть не ответила»
    property bool subMissing: false

    // Хосты статуса: основной за Cloudflare, запасной — прямой адрес нашего сервера.
    // Нужен, потому что диапазон Cloudflare у части операторов блокируется: карточка
    // тогда просто не появлялась. Повтор идёт на ДРУГОЙ хост, а не на тот же.
    readonly property var subInfoHosts: ["https://webhook.cottonvpn.com",
                                         "https://origin.cottonvpn.com:9443"]

    Timer {
        id: subInfoRetryTimer
        interval: 4000
        repeat: false
        onTriggered: root.refreshSubInfo(1)
    }

    function refreshSubInfo(hostIndex) {
        var idx = hostIndex || 0
        if (!root.hasServer) { root.subInfo = null; root.subMissing = false; return }
        // AWG-ключ опознаётся по pubkey, Reality-ключ — по UUID клиента
        var pub = ServersUiController.getDefaultServerAwgClientPubKey()
        var uuid = pub ? "" : ServersUiController.getDefaultServerXrayClientId()
        if (!pub && !uuid) { root.subInfo = null; root.subMissing = false; return }
        var url = root.subInfoHosts[idx] + "/app/status?"
                + (pub ? "pub=" + encodeURIComponent(pub) : "uuid=" + encodeURIComponent(uuid))
                + "&v=" + encodeURIComponent(SettingsController.getReleaseVersion())
        var xhr = new XMLHttpRequest()
        xhr.open("GET", url)
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status === 200) {
                try {
                    root.subInfo = JSON.parse(xhr.responseText)
                    root.subMissing = false
                    subCache.lastStatus = xhr.responseText
                } catch (e) {}
            } else if (xhr.status === 404) {
                // сервер ответил: ключа нет в базе — подписки нет, повторять бессмысленно
                root.subInfo = null
                root.subMissing = true
                subCache.lastStatus = ""
            } else if (idx + 1 < root.subInfoHosts.length) {
                subInfoRetryTimer.start()   // сеть не ответила — пробуем прямой адрес
            }
        }
        xhr.send()
    }

    // Черновая сборка? Версия с суффиксом через дефис (1.4.3-rc7) — такие ставит только
    // владелец для проверки. В них ведём журнал и отправляем его при запуске, чтобы
    // разбирать поломки по факту, а не по описанию. В обычных релизах ничего этого нет:
    // кнопку отправки владелец просил убрать (2026-08-11).
    readonly property bool draftBuild: SettingsController.getReleaseVersion().indexOf("-") >= 0

    function uploadLogs(hostIndex) {
        var idx = hostIndex || 0
        var pub = ServersUiController.getDefaultServerAwgClientPubKey()
        var uuid = pub ? "" : ServersUiController.getDefaultServerXrayClientId()
        var url = root.subInfoHosts[idx] + "/app/logs?"
                + (pub ? "pub=" + encodeURIComponent(pub) : "uuid=" + encodeURIComponent(uuid))
        var xhr = new XMLHttpRequest()
        xhr.open("POST", url)
        xhr.setRequestHeader("Content-Type", "text/plain; charset=utf-8")
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status !== 200 && idx + 1 < root.subInfoHosts.length) {
                root.uploadLogs(idx + 1)     // основной адрес недоступен — пробуем прямой
            }
        }
        var logs = SettingsController.collectLogsForUpload()
        if (logs.length < 200) return    // писать ещё нечего
        xhr.send(logs)
    }

    // подписки нет или она кончилась — подключаться бессмысленно, туннель просто не встанет
    readonly property bool subBlocksConnect: root.subMissing
                                             || (root.subInfo !== null && root.subInfo.active === false)

    function daysWord(n) {
        var m10 = n % 10, m100 = n % 100
        if (m10 === 1 && m100 !== 11) return qsTr("день")
        if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return qsTr("дня")
        return qsTr("дней")
    }

    Component.onCompleted: {
        if (root.draftBuild) {
            // в черновой: включаем журнал и отправляем накопленное за прошлый запуск —
            // именно там окажется момент поломки, о которой владелец расскажет словами
            if (!SettingsController.isLoggingEnabled) {
                SettingsController.isLoggingEnabled = true
            }
            root.uploadLogs()
        }
        // сперва показываем последнее известное — экран не должен быть пустым,
        // пока идёт запрос (или если сеть до сервера сейчас не достаёт)
        if (subCache.lastStatus !== "") {
            try { root.subInfo = JSON.parse(subCache.lastStatus) } catch (e) {}
        }
        refreshSubInfo()
    }
    onIsOnChanged: refreshSubInfo()
    onHasServerChanged: refreshSubInfo()

    // возврат в приложение — перезапрашиваем: если карточка не появилась из-за
    // недоступной сети, ждать до следующего 15-минутного тика бессмысленно
    Connections {
        target: Qt.application
        function onStateChanged() {
            if (Qt.application.state === Qt.ApplicationActive) root.refreshSubInfo()
        }
    }

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

    // фон-градиент как на сайте (тёмный — те же сиреневые тона, глубокие)
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0;  color: root.darkMode ? "#17122E" : "#FBF8FF" }
            GradientStop { position: 0.55; color: root.darkMode ? "#1C1638" : "#F4EEFB" }
            GradientStop { position: 1.0;  color: root.darkMode ? "#191330" : "#FBF6FF" }
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

            Rectangle {
                Layout.fillWidth: true
                radius: 16
                color: root.cCard
                border.color: root.cLine
                border.width: 1
                implicitHeight: themeRow.implicitHeight + 24

                RowLayout {
                    id: themeRow
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
                            text: qsTr("🌙 Тёмная тема")
                            color: root.cInk
                            font.family: "PT Root UI VF"
                            font.weight: 600
                            font.pixelSize: 15
                        }
                        Text {
                            text: themeSettings.theme === "auto" ? qsTr("Сейчас: как в системе")
                                                                 : qsTr("Выбрана вручную")
                            color: root.cMuted
                            font.family: "PT Root UI VF"
                            font.pixelSize: 12
                        }
                    }

                    Switch {
                        checked: root.darkMode
                        onToggled: themeSettings.theme = checked ? "dark" : "light"
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

            // без активной подписки не даём уйти в бесконечное «Подключение…»
            connectGuard: function() {
                if (!root.subBlocksConnect) return true
                PageController.showNotificationMessage(
                    root.subMissing ? qsTr("Подписка не найдена — оформи её в боте и добавь ключ заново")
                                    : qsTr("Подписка закончилась — продли её в боте, и VPN снова заработает"))
                return false
            }

            defaultButtonColor: root.cMuted        // кольцо/глиф когда выключено
            connectedButtonColor: root.cGreen      // кольцо когда включено
            connectedFillColor: root.cGreen        // заливка круга когда включено
            offFillColor: root.cCard               // круг когда выключено (белый/тёмный)
            glowColor: root.cViolet
            ringBorderColor: root.cLine
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
                    color: root.isOn ? root.cGreen : (root.isBusy ? root.cViolet : (root.darkMode ? "#4A4370" : "#C7C2DE"))

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

        // подписки нет или истекла — говорим прямо, а не прячем карточку молча
        Rectangle {
            visible: !root.showKeyField && root.subBlocksConnect
            Layout.fillWidth: true
            Layout.topMargin: 18
            radius: 16
            color: root.cCard
            border.color: root.cLine
            border.width: 1
            implicitHeight: subGoneText.implicitHeight + 28

            Text {
                id: subGoneText
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                text: root.subMissing ? qsTr("Подписка не найдена — оформи её в боте и добавь ключ заново")
                                      : qsTr("Подписка закончилась — продли её в боте")
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
                textColor: "#FFFFFF"

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
