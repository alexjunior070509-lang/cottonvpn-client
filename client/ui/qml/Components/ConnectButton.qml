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
                radius: 10
                samples: 25
                color: root.buttonActiveFocus ? AmneziaStyle.color.paleGray : AmneziaStyle.color.goldenApricot
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

            property color glyphColor: ConnectionController.isConnected ? root.connectedButtonColor : root.defaultButtonColor

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
