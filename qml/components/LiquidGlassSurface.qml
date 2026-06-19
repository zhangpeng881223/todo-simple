import QtQuick 2.15
import org.deepin.dtk 1.0 as D

Rectangle {
    id: surface

    property bool lightTheme: true
    property string variant: "control"
    property bool interactive: false
    property bool hovered: false
    property bool active: false
    property bool pressed: false
    property bool blurEnabled: true
    property real protection: 0
    property real density: variant === "window" ? 0.18 : (variant === "readability" ? 0.14 : (variant === "frosted" ? 0.22 : (variant === "panel" ? 0.34 : 0.68)))
    property real tintOpacity: lightTheme ? (variant === "window" ? 0.30 : 0.34) : (variant === "window" ? 0.46 : 0.18)
    property real edgeOpacity: lightTheme ? 0.48 : 0.18
    property real highlightOpacity: lightTheme ? 0.46 : 0.16
    property real glowOpacity: active ? 0.30 : (hovered ? 0.20 : 0.08)
    property real lensOpacity: variant === "window" ? 0.12 : (variant === "readability" ? 0 : (variant === "frosted" ? 0.04 : (variant === "panel" ? 0.22 : 0.38)))
    property real chromaOpacity: variant === "window" ? 0.025 : (variant === "readability" ? 0 : (variant === "frosted" ? 0 : (variant === "panel" ? 0.055 : 0.080)))
    property real thicknessOpacity: variant === "panel" ? 0.36 : 0.18
    property color tintColor: lightTheme ? Qt.rgba(1, 1, 1, tintOpacity)
                                      : Qt.rgba(1, 1, 1, tintOpacity)
    property color blendColor: lightTheme ? Qt.rgba(1, 1, 1, 0.30)
                                       : Qt.rgba(0.08, 0.09, 0.10, 0.58)
    property color accentColor: "#2ea3ff"

    property real hoverProgress: hovered || active ? 1 : 0
    property real pressProgress: pressed ? 1 : 0
    property real shimmer: 0
    readonly property bool frostedMode: variant === "frosted"
    readonly property bool readabilityMode: variant === "readability"
    readonly property bool windowMode: variant === "window"
    readonly property real panelMode: variant === "panel" || variant === "frosted" ? 1 : 0
    readonly property bool opticsMode: !frostedMode && !windowMode && !readabilityMode
    readonly property real effectiveDensity: Math.min(1, Math.max(0, density + hoverProgress * 0.16 + pressProgress * 0.08))

    function outlineColor() {
        if (surface.lightTheme) {
            if (surface.windowMode)
                return Qt.rgba(1, 1, 1, 0.24)
            if (surface.readabilityMode)
                return Qt.rgba(1, 1, 1, Math.min(surface.edgeOpacity, 0.18))
            if (surface.frostedMode)
                return Qt.rgba(1, 1, 1, Math.min(surface.edgeOpacity, 0.34))
            return Qt.rgba(1, 1, 1, surface.edgeOpacity)
        }
        if (surface.windowMode)
            return Qt.rgba(1, 1, 1, 0.10)
        if (surface.readabilityMode)
            return Qt.rgba(1, 1, 1, Math.max(0.05, surface.edgeOpacity))
        return Qt.rgba(1, 1, 1, Math.max(0.08, surface.edgeOpacity))
    }

    color: "transparent"
    border.width: 0
    antialiasing: true
    clip: true
    scale: pressed ? (variant === "panel" ? 0.998 : 0.975) : 1.0

    Behavior on hoverProgress { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    Behavior on pressProgress { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    Behavior on protection { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    Behavior on tintColor { ColorAnimation { duration: 260; easing.type: Easing.OutCubic } }
    Behavior on blendColor { ColorAnimation { duration: 260; easing.type: Easing.OutCubic } }

    NumberAnimation on shimmer {
        from: 0
        to: 1
        duration: surface.panelMode ? 9000 : 5200
        loops: Animation.Infinite
        running: surface.visible && surface.opticsMode && (surface.hovered || surface.active || surface.pressed)
    }

    Loader {
        id: blurLoader
        anchors.fill: parent
        active: surface.blurEnabled
        sourceComponent: Component {
            D.StyledBehindWindowBlur {
                control: surface
                anchors.fill: parent
                cornerRadius: surface.radius
                blendColor: valid ? surface.blendColor : surface.tintColor
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: surface.radius
        antialiasing: true
        visible: surface.windowMode || (surface.readabilityMode && (!surface.blurEnabled || !blurLoader.item || !blurLoader.item.valid))
        color: surface.tintColor
    }

    Rectangle {
        anchors.fill: parent
        radius: surface.radius
        antialiasing: true
        visible: !surface.windowMode && !surface.readabilityMode
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop {
                position: 0.0
                color: surface.windowMode
                       ? surface.tintColor
                       : (surface.lightTheme
                       ? Qt.rgba(1, 1, 1, surface.tintOpacity + (surface.panelMode ? (surface.frostedMode ? 0.02 : 0.06) : 0.12))
                       : Qt.rgba(1, 1, 1, 0.08))
            }
            GradientStop {
                position: 0.52
                color: surface.tintColor
            }
            GradientStop {
                position: 1.0
                color: surface.windowMode
                       ? surface.tintColor
                       : (surface.lightTheme
                       ? (surface.frostedMode
                          ? Qt.rgba(1, 1, 1, Math.max(0.12, surface.tintOpacity - 0.10))
                          : Qt.rgba(236 / 255, 1, 242 / 255, Math.max(0.08, surface.tintOpacity - 0.20)))
                       : Qt.rgba(1, 1, 1, 0.04))
            }
        }
    }

    Canvas {
        id: opticsCanvas
        anchors.fill: parent
        visible: surface.opticsMode
        opacity: surface.highlightOpacity
        antialiasing: true

        function roundedPath(ctx, x, y, w, h, r) {
            r = Math.max(0, Math.min(r, Math.min(w, h) / 2))
            ctx.beginPath()
            ctx.moveTo(x + r, y)
            ctx.lineTo(x + w - r, y)
            ctx.quadraticCurveTo(x + w, y, x + w, y + r)
            ctx.lineTo(x + w, y + h - r)
            ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h)
            ctx.lineTo(x + r, y + h)
            ctx.quadraticCurveTo(x, y + h, x, y + h - r)
            ctx.lineTo(x, y + r)
            ctx.quadraticCurveTo(x, y, x + r, y)
            ctx.closePath()
        }

        function strokeRounded(ctx, inset, alpha, color, lineWidth) {
            ctx.save()
            ctx.globalAlpha = alpha
            ctx.strokeStyle = color
            ctx.lineWidth = lineWidth
            roundedPath(ctx, inset, inset, width - inset * 2, height - inset * 2, surface.radius - inset)
            ctx.stroke()
            ctx.restore()
        }

        onPaint: {
            var ctx = getContext("2d")
            var w = width
            var h = height
            if (w <= 0 || h <= 0) return
            var d = surface.effectiveDensity
            var hp = surface.hoverProgress
            var pp = surface.pressProgress
            var panel = surface.panelMode
            var t = surface.shimmer
            ctx.clearRect(0, 0, w, h)

            var top = ctx.createLinearGradient(0, 0, w, Math.max(1, h * 0.48))
            top.addColorStop(0.0, "rgba(255,255,255," + (surface.lightTheme ? (surface.windowMode ? 0.16 : (panel ? 0.22 : 0.34)) * d : 0.10 * d) + ")")
            top.addColorStop(0.58, "rgba(255,255,255," + (surface.lightTheme ? (surface.windowMode ? 0.035 : (panel ? 0.05 : 0.09)) * d : 0.04 * d) + ")")
            top.addColorStop(1.0, "rgba(255,255,255,0)")
            ctx.fillStyle = top
            roundedPath(ctx, 1, 1, w - 2, h - 2, surface.radius - 1)
            ctx.fill()

            var bottom = ctx.createLinearGradient(0, h * 0.62, 0, h)
            bottom.addColorStop(0.0, "rgba(255,255,255,0)")
            bottom.addColorStop(0.72, "rgba(215,255,230," + (surface.lightTheme ? (surface.windowMode ? 0.010 : (panel ? 0.025 : 0.040)) + 0.020 * d : (surface.windowMode ? 0.002 : 0.02)) + ")")
            bottom.addColorStop(1.0, "rgba(0,0,0," + (surface.lightTheme ? (surface.windowMode ? 0.006 : (panel ? 0.012 : 0.024)) + 0.010 * d : (surface.windowMode ? 0.006 : 0.10)) + ")")
            ctx.fillStyle = bottom
            roundedPath(ctx, 1, 1, w - 2, h - 2, surface.radius - 1)
            ctx.fill()

            strokeRounded(ctx, 0.70, surface.lightTheme ? (surface.frostedMode ? 0.42 : (surface.windowMode ? 0.46 : (panel ? 0.70 : 0.78))) : (surface.windowMode ? 0.030 : 0.12), "rgba(255,255,255,1)", 1.0)
            strokeRounded(ctx, 1.70, surface.lightTheme ? (surface.frostedMode ? 0.028 : (panel ? 0.030 : 0.040) + 0.018 * hp) : (surface.windowMode ? 0.030 : 0.12), "rgba(0,0,0,1)", 1.0)
            if (!surface.frostedMode) {
                strokeRounded(ctx, 3.0, surface.lightTheme ? surface.chromaOpacity + 0.040 * hp : 0.06, "rgba(120,205,255,1)", panel ? 0.65 : 0.85)
            }

            ctx.save()
            ctx.globalAlpha = surface.frostedMode ? 0 : ((surface.windowMode ? 0.016 : (panel ? 0.035 : 0.075)) + hp * 0.075 + pp * 0.080)
            ctx.strokeStyle = "rgba(105,190,255,1)"
            ctx.lineWidth = panel ? 0.8 : 1.0
            roundedPath(ctx, 4.0, 4.0, w - 8.0, h - 8.0, surface.radius - 4.0)
            ctx.stroke()
            ctx.strokeStyle = "rgba(255,135,210,0.60)"
            ctx.lineWidth = panel ? 0.55 : 0.65
            roundedPath(ctx, 5.2, 5.2, w - 10.4, h - 10.4, surface.radius - 5.2)
            ctx.stroke()
            ctx.restore()

            ctx.save()
            roundedPath(ctx, 2, 2, w - 4, h - 4, surface.radius - 2)
            ctx.clip()
            var lens = ctx.createRadialGradient(w * 0.18, h * 0.06, Math.max(1, w * 0.04),
                                                w * 0.18, h * 0.06, Math.max(w, h) * (panel ? 0.78 : 0.96))
            lens.addColorStop(0.0, "rgba(255,255,255," + (surface.lensOpacity + (surface.frostedMode ? 0 : hp * 0.05)) + ")")
            lens.addColorStop(0.42, "rgba(255,255,255," + (surface.lensOpacity * 0.26) + ")")
            lens.addColorStop(1.0, "rgba(255,255,255,0)")
            ctx.fillStyle = lens
            ctx.fillRect(0, 0, w, h)
            var innerShade = ctx.createRadialGradient(w * 1.04, h * 1.05, Math.max(1, w * 0.10),
                                                      w * 1.04, h * 1.05, Math.max(w, h) * 0.70)
            innerShade.addColorStop(0.0, "rgba(0,0,0," + (surface.windowMode ? 0.018 : (panel ? 0.034 : 0.042)) + ")")
            innerShade.addColorStop(0.55, "rgba(0,0,0," + (surface.windowMode ? 0.006 : (panel ? 0.010 : 0.016)) + ")")
            innerShade.addColorStop(1.0, "rgba(0,0,0,0)")
            ctx.fillStyle = innerShade
            ctx.fillRect(0, 0, w, h)
            ctx.restore()

            var sweepX = -w * 0.30 + (w * 1.60) * ((t + hp * 0.12) % 1.0)
            var sweep = ctx.createLinearGradient(sweepX - w * 0.26, 0, sweepX + w * 0.26, h)
            sweep.addColorStop(0.00, "rgba(255,255,255,0)")
            sweep.addColorStop(0.46, "rgba(255,255,255," + ((surface.windowMode ? 0.018 : (panel ? 0.035 : 0.10)) + hp * 0.10) + ")")
            sweep.addColorStop(0.54, "rgba(175,230,255," + ((surface.windowMode ? 0.010 : (panel ? 0.018 : 0.055)) + hp * 0.070) + ")")
            sweep.addColorStop(1.00, "rgba(255,255,255,0)")
            ctx.save()
            roundedPath(ctx, 2, 2, w - 4, h - 4, surface.radius - 2)
            ctx.clip()
            ctx.fillStyle = sweep
            ctx.translate(w * 0.50, h * 0.50)
            ctx.rotate(-0.18)
            ctx.fillRect(-w, -h, w * 2.2, h * 2.2)
            ctx.restore()

            var causticAlpha = surface.frostedMode ? 0 : ((surface.windowMode ? 0.010 : (panel ? 0.018 : 0.044)) + hp * 0.036)
            ctx.save()
            roundedPath(ctx, 2, 2, w - 4, h - 4, surface.radius - 2)
            ctx.clip()
            ctx.globalAlpha = causticAlpha
            ctx.strokeStyle = "rgba(255,255,255,1)"
            ctx.lineWidth = panel ? 0.55 : 0.8
            for (var i = 0; i < (surface.windowMode ? 3 : (panel ? 4 : 3)); ++i) {
                var y = h * (0.18 + i * 0.16) + Math.sin((t + i) * 6.283) * (panel ? 9 : 3)
                ctx.beginPath()
                ctx.moveTo(w * 0.10, y)
                ctx.bezierCurveTo(w * 0.28, y - h * 0.05, w * 0.62, y + h * 0.07, w * 0.90, y - h * 0.02)
                ctx.stroke()
            }
            ctx.restore()
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections {
            target: surface
            function onShimmerChanged() { opticsCanvas.requestPaint() }
            function onHoverProgressChanged() { opticsCanvas.requestPaint() }
            function onPressProgressChanged() { opticsCanvas.requestPaint() }
            function onDensityChanged() { opticsCanvas.requestPaint() }
            function onLensOpacityChanged() { opticsCanvas.requestPaint() }
            function onChromaOpacityChanged() { opticsCanvas.requestPaint() }
            function onThicknessOpacityChanged() { opticsCanvas.requestPaint() }
            function onLightThemeChanged() { opticsCanvas.requestPaint() }
            function onRadiusChanged() { opticsCanvas.requestPaint() }
        }
    }

    Canvas {
        id: panelOpticsCanvas
        anchors.fill: parent
        visible: surface.variant === "panel" && surface.thicknessOpacity > 0.001
        opacity: surface.lightTheme ? surface.thicknessOpacity : surface.thicknessOpacity * 0.38
        antialiasing: true

        function roundedPath(ctx, x, y, w, h, r) {
            r = Math.max(0, Math.min(r, Math.min(w, h) / 2))
            ctx.beginPath()
            ctx.moveTo(x + r, y)
            ctx.lineTo(x + w - r, y)
            ctx.quadraticCurveTo(x + w, y, x + w, y + r)
            ctx.lineTo(x + w, y + h - r)
            ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h)
            ctx.lineTo(x + r, y + h)
            ctx.quadraticCurveTo(x, y + h, x, y + h - r)
            ctx.lineTo(x, y + r)
            ctx.quadraticCurveTo(x, y, x + r, y)
            ctx.closePath()
        }

        onPaint: {
            var ctx = getContext("2d")
            var w = width
            var h = height
            if (w <= 0 || h <= 0) return
            ctx.clearRect(0, 0, w, h)
            roundedPath(ctx, 1, 1, w - 2, h - 2, surface.radius - 1)
            ctx.clip()

            var leftEdge = ctx.createLinearGradient(0, 0, Math.min(54, w * 0.20), 0)
            leftEdge.addColorStop(0.00, "rgba(255,255,255,0.46)")
            leftEdge.addColorStop(0.18, "rgba(255,255,255,0.20)")
            leftEdge.addColorStop(0.70, "rgba(255,255,255,0.035)")
            leftEdge.addColorStop(1.00, "rgba(255,255,255,0)")
            ctx.fillStyle = leftEdge
            ctx.fillRect(0, 0, Math.min(58, w * 0.22), h)

            var rightEdge = ctx.createLinearGradient(w - Math.min(70, w * 0.25), 0, w, 0)
            rightEdge.addColorStop(0.00, "rgba(255,255,255,0)")
            rightEdge.addColorStop(0.52, "rgba(255,255,255,0.035)")
            rightEdge.addColorStop(0.86, "rgba(255,255,255,0.24)")
            rightEdge.addColorStop(1.00, "rgba(255,255,255,0.54)")
            ctx.fillStyle = rightEdge
            ctx.fillRect(w - Math.min(74, w * 0.27), 0, Math.min(74, w * 0.27), h)

            var topLens = ctx.createRadialGradient(w * 0.18, h * 0.03, 1, w * 0.18, h * 0.03, Math.max(w, h) * 0.42)
            topLens.addColorStop(0.00, "rgba(255,255,255,0.48)")
            topLens.addColorStop(0.38, "rgba(255,255,255,0.12)")
            topLens.addColorStop(1.00, "rgba(255,255,255,0)")
            ctx.fillStyle = topLens
            ctx.fillRect(0, 0, w, h)

            var bottomLens = ctx.createRadialGradient(w * 0.82, h * 1.03, 1, w * 0.82, h * 1.03, Math.max(w, h) * 0.38)
            bottomLens.addColorStop(0.00, "rgba(0,0,0,0.13)")
            bottomLens.addColorStop(0.52, "rgba(0,0,0,0.034)")
            bottomLens.addColorStop(1.00, "rgba(0,0,0,0)")
            ctx.fillStyle = bottomLens
            ctx.fillRect(0, 0, w, h)

            var greenLift = ctx.createLinearGradient(0, h * 0.78, 0, h)
            greenLift.addColorStop(0.00, "rgba(230,255,238,0)")
            greenLift.addColorStop(0.56, "rgba(226,255,232,0.15)")
            greenLift.addColorStop(1.00, "rgba(255,255,255,0.22)")
            ctx.fillStyle = greenLift
            ctx.fillRect(0, h * 0.72, w, h * 0.28)

            ctx.globalAlpha = 0.28
            ctx.strokeStyle = "rgba(255,255,255,1)"
            ctx.lineWidth = 1.2
            ctx.beginPath()
            ctx.moveTo(w * 0.10, h * 0.045)
            ctx.bezierCurveTo(w * 0.28, h * 0.020, w * 0.62, h * 0.032, w * 0.90, h * 0.058)
            ctx.stroke()

            ctx.globalAlpha = 0.12
            ctx.strokeStyle = "rgba(115,200,255,1)"
            ctx.lineWidth = 0.9
            ctx.beginPath()
            ctx.moveTo(w - 6, surface.radius + 14)
            ctx.bezierCurveTo(w - 18, h * 0.28, w - 14, h * 0.66, w - 7, h - surface.radius - 16)
            ctx.stroke()
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections {
            target: surface
            function onThicknessOpacityChanged() { panelOpticsCanvas.requestPaint() }
            function onLightThemeChanged() { panelOpticsCanvas.requestPaint() }
            function onRadiusChanged() { panelOpticsCanvas.requestPaint() }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: surface.radius
        color: "transparent"
        border.width: 1
        border.color: surface.outlineColor()
        antialiasing: true
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, surface.radius - 1)
        color: "transparent"
        border.width: surface.frostedMode || surface.windowMode || surface.readabilityMode ? 0 : 1
        border.color: surface.lightTheme
                      ? Qt.rgba(0, 0, 0, surface.variant === "panel" ? 0.036 : 0.060 + surface.hoverProgress * 0.030)
                      : Qt.rgba(0, 0, 0, 0.14)
        antialiasing: true
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: surface.variant === "panel" ? 10 : 8
        anchors.rightMargin: surface.variant === "panel" ? 10 : 8
        anchors.topMargin: 1
        height: 1
        radius: 1
        opacity: surface.frostedMode || surface.windowMode || surface.readabilityMode ? 0 : (surface.lightTheme ? (surface.panelMode ? 0.32 : 0.58) : 0.10)
        color: Qt.rgba(1, 1, 1, 0.90)
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: surface.frostedMode || surface.windowMode || surface.readabilityMode ? 0 : (surface.panelMode ? 12 : 5)
        radius: surface.radius
        color: surface.lightTheme
               ? Qt.rgba(0, 0, 0, surface.panelMode ? 0.018 : 0.030 + surface.hoverProgress * 0.018)
               : Qt.rgba(0, 0, 0, 0.12)
        antialiasing: true
    }

    Rectangle {
        property real rimInset: surface.variant === "panel" ? 2 : 1
        anchors.fill: parent
        anchors.margins: rimInset
        radius: Math.max(0, surface.radius - rimInset)
        color: "transparent"
        border.width: surface.windowMode || surface.readabilityMode ? 0 : (surface.hoverProgress > 0.01 || surface.active ? 1 : 0)
        border.color: surface.active
                      ? Qt.rgba(46 / 255, 163 / 255, 1, 0.32)
                      : Qt.rgba(1, 1, 1, surface.glowOpacity)
        antialiasing: true
    }
}
