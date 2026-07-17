import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import Qt5Compat.GraphicalEffects

import ConnectionState 1.0
import PageEnum 1.0
import Style 1.0

Button {
    id: root

    property string defaultButtonColor: AmneziaStyle.color.paleGray
    property string progressButtonColor: AmneziaStyle.color.paleGray
    property string connectedButtonColor: AmneziaStyle.color.goldenApricot
    // CottonVPN: заливка круга и подсветка по состоянию (явный вкл/выкл)
    property string connectedFillColor: "#10B981"   // зелёный — VPN включён
    property string offFillColor: "#FFFFFF"          // белый — выключен
    property string glowColor: "#7C5CFF"             // сиреневая подсветка (как на сайте)
    property string ringBorderColor: "#ECE7F8"       // ободок круга (в тёмной теме темнее)
    property bool buttonActiveFocus: activeFocus && (Qt.platform.os !== "android" || SettingsController.isOnTv())

    property bool isFocusable: true
    
    Keys.onTabPressed: {
        FocusController.nextKeyTabItem()
    }

    Keys.onBacktabPressed: {
        FocusController.previousKeyTabItem()
    }

    Keys.onUpPressed: {
        FocusController.nextKeyUpItem()
    }
    
    Keys.onDownPressed: {
        FocusController.nextKeyDownItem()
    }
    
    Keys.onLeftPressed: {
        FocusController.nextKeyLeftItem()
    }

    Keys.onRightPressed: {
        FocusController.nextKeyRightItem()
    }
        
    implicitWidth: 190
    implicitHeight: 190

    text: ConnectionController.connectionStateText

    Connections {
        target: ConnectionController

        function onPreparingConfig() {
            PageController.showNotificationMessage(qsTr("Unable to disconnect during configuration preparation"))
        }
    }

//    enabled: !ConnectionController.isConnectionInProgress

    background: Item {
        implicitWidth: parent.width
        implicitHeight: parent.height
        transformOrigin: Item.Center

        // Заливка круга: зелёная когда подключено, белая когда выключено
        Rectangle {
            id: fillDisc
            anchors.centerIn: parent
            width: 176
            height: 176
            radius: width / 2
            color: {
                if (ConnectionController.isConnectionInProgress) return root.offFillColor
                return ConnectionController.isConnected ? root.connectedFillColor : root.offFillColor
            }
            border.width: ConnectionController.isConnected ? 0 : 1
            border.color: root.ringBorderColor
            Behavior on color { ColorAnimation { duration: 250 } }
        }

        Shape {
            id: backgroundCircle
            width: parent.implicitWidth
            height: parent.implicitHeight
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            layer.enabled: true
            layer.samples: 4
            layer.smooth: true
            layer.effect: DropShadow {
                anchors.fill: backgroundCircle
                horizontalOffset: 0
                verticalOffset: 0
                radius: ConnectionController.isConnected ? 24 : 12
                samples: 25
                color: ConnectionController.isConnected ? root.connectedFillColor : root.glowColor
                source: backgroundCircle
            }

            ShapePath {
                fillColor: AmneziaStyle.color.transparent
                strokeColor: AmneziaStyle.color.paleGray
                strokeWidth: root.buttonActiveFocus ? 1 : 0
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: backgroundCircle.width / 2
                    centerY: backgroundCircle.height / 2
                    radiusX: 94
                    radiusY: 94
                    startAngle: 0
                    sweepAngle: 360
                }
            }

            ShapePath {
                fillColor: AmneziaStyle.color.transparent
                strokeColor: {
                    if (ConnectionController.isConnectionInProgress) {
                        return AmneziaStyle.color.darkCharcoal
                    } else if (ConnectionController.isConnected) {
                        return connectedButtonColor
                    } else {
                        return defaultButtonColor
                    }
                }
                strokeWidth: root.buttonActiveFocus ? 2 : 3
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: backgroundCircle.width / 2
                    centerY: backgroundCircle.height / 2
                    radiusX: 93 - (root.buttonActiveFocus ? 2 : 0)
                    radiusY: 93 - (root.buttonActiveFocus ? 2 : 0)
                    startAngle: 0
                    sweepAngle: 360
                }
            }

            MouseArea {
                anchors.fill: parent

                cursorShape: Qt.PointingHandCursor
                enabled: false
            }
        }

        Shape {
            id: shape
            width: parent.implicitWidth
            height: parent.implicitHeight
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            layer.enabled: true
            layer.samples: 4

            visible: ConnectionController.isConnectionInProgress

            ShapePath {
                fillColor: AmneziaStyle.color.transparent
                strokeColor: AmneziaStyle.color.paleGray
                strokeWidth: 3
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: shape.width / 2
                    centerY: shape.height / 2
                    radiusX: 93
                    radiusY: 93
                    startAngle: 245
                    sweepAngle: -180
                }
            }

            RotationAnimator {
                target: shape
                running: ConnectionController.isConnectionInProgress
                from: 0
                to: 360
                loops: Animation.Infinite
                duration: 1000
            }
        }
    }

    contentItem: Item {
        anchors.fill: parent

        Canvas {
            id: powerGlyph
            anchors.centerIn: parent
            width: 72
            height: 72

            // На зелёной заливке (подключено) глиф белый; иначе — цвет состояния
            property color glyphColor: ConnectionController.isConnected ? "#FFFFFF" : root.defaultButtonColor

            onGlyphColorChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var cx = width / 2
                var cy = height / 2
                var r = 22
                ctx.lineWidth = 5
                ctx.lineCap = "round"
                ctx.strokeStyle = glyphColor

                // кольцо с разрывом сверху
                var gap = 0.42 // половина разрыва в радианах
                ctx.beginPath()
                ctx.arc(cx, cy, r, -Math.PI / 2 + gap, -Math.PI / 2 - gap + 2 * Math.PI, false)
                ctx.stroke()

                // вертикальная черта (символ питания)
                ctx.beginPath()
                ctx.moveTo(cx, cy - 4)
                ctx.lineTo(cx, cy - r - 6)
                ctx.stroke()
            }
        }
    }

    onClicked: {
        ConnectionController.connectButtonClicked()
    }

    Keys.onEnterPressed: this.clicked()
    Keys.onReturnPressed: this.clicked()
}
