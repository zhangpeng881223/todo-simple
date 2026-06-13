import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Particles 2.15

Item {
    id: root
    width: 1280
    height: 720
    visible: effectRunning

    property string effectMode: ""
    property var powderParticles: []
    property bool effectRunning: false
    property int fireworkCount: 0
    property real powderProgress: 0
    readonly property var fireworkPalette: [
        { group: "gold", flash: "#ffb000" },
        { group: "crimson", flash: "#ff2727" },
        { group: "rose", flash: "#ff1f78" },
        { group: "emerald", flash: "#12e861" },
        { group: "azure", flash: "#168fff" },
        { group: "violet", flash: "#8b35ff" },
        { group: "orange", flash: "#ff6817" }
    ]

    function start(mode, particles) {
        effectMode = mode
        powderParticles = particles || []
        console.log("effects overlay start", effectMode, powderParticles.length)
        if (effectMode === "powder" && powderParticles.length > 0) {
            console.log("effects powder first particle", JSON.stringify(powderParticles[0]))
        }
        effectRunning = true
        powderProgress = 0
        if (effectMode === "fireworks") {
            finishTimer.interval = 10000
            Qt.callLater(function() {
                fireworksTimer.start()
                launchFirework()
            })
        } else {
            finishTimer.interval = 3200
            powderClock.restart()
        }
        finishTimer.restart()
    }

    function particleValue(particle, key, fallbackValue) {
        if (!particle)
            return fallbackValue
        var value = particle[key]
        return value === undefined || value === null ? fallbackValue : value
    }

    function launchFirework() {
        if (effectMode !== "fireworks")
            return
        var margin = 80
        var x = margin + Math.random() * Math.max(1, width - margin * 2)
        var y = 45 + Math.random() * Math.max(1, height * 0.64)
        launchFireworkBurst(x, y)
        if (Math.random() > 0.48) {
            var secondX = margin + Math.random() * Math.max(1, width - margin * 2)
            var secondY = 45 + Math.random() * Math.max(1, height * 0.58)
            launchFireworkBurst(secondX, secondY)
        }
        fireworkCount += 1
    }

    function launchFireworkBurst(x, y) {
        var choiceIndex = Math.floor(Math.random() * fireworkPalette.length)
        var choice = fireworkPalette[choiceIndex]
        var accent = fireworkPalette[(choiceIndex + 2 + Math.floor(Math.random() * 3)) % fireworkPalette.length]
        fireworkEmitter.group = choice.group
        fireworkEmitter.burst(285, x, y)
        accentEmitter.group = accent.group
        accentEmitter.burst(135, x, y)
        sparkEmitter.group = Math.random() > 0.5 ? "gold" : "orange"
        sparkEmitter.burst(36, x, y)
        flashDot.x = x - flashDot.width / 2
        flashDot.y = y - flashDot.height / 2
        flashDot.color = choice.flash
        flash.restart()
    }

    function finish() {
        fireworksTimer.stop()
        if (Window.window) {
            Window.window.close()
        }
    }

    ParticleSystem {
        id: fireworksSystem
        running: root.effectMode === "fireworks" && root.effectRunning
    }

    ImageParticle {
        system: fireworksSystem
        groups: ["gold"]
        source: "qrc:/assets/firework-gold.svg"
        colorVariation: 0
        alpha: 1
        entryEffect: ImageParticle.Fade
    }

    ImageParticle {
        system: fireworksSystem
        groups: ["crimson"]
        source: "qrc:/assets/firework-crimson.svg"
        colorVariation: 0
        alpha: 1
        entryEffect: ImageParticle.Fade
    }

    ImageParticle {
        system: fireworksSystem
        groups: ["rose"]
        source: "qrc:/assets/firework-rose.svg"
        colorVariation: 0
        alpha: 1
        entryEffect: ImageParticle.Fade
    }

    ImageParticle {
        system: fireworksSystem
        groups: ["emerald"]
        source: "qrc:/assets/firework-emerald.svg"
        colorVariation: 0
        alpha: 1
        entryEffect: ImageParticle.Fade
    }

    ImageParticle {
        system: fireworksSystem
        groups: ["azure"]
        source: "qrc:/assets/firework-azure.svg"
        colorVariation: 0
        alpha: 1
        entryEffect: ImageParticle.Fade
    }

    ImageParticle {
        system: fireworksSystem
        groups: ["violet"]
        source: "qrc:/assets/firework-violet.svg"
        colorVariation: 0
        alpha: 1
        entryEffect: ImageParticle.Fade
    }

    ImageParticle {
        system: fireworksSystem
        groups: ["orange"]
        source: "qrc:/assets/firework-orange.svg"
        colorVariation: 0
        alpha: 1
        entryEffect: ImageParticle.Fade
    }

    Emitter {
        id: fireworkEmitter
        system: fireworksSystem
        group: "gold"
        emitRate: 0
        lifeSpan: 1700
        lifeSpanVariation: 620
        size: 8
        endSize: 1
        sizeVariation: 6
        velocity: AngleDirection {
            angle: 0
            angleVariation: 360
            magnitude: 315
            magnitudeVariation: 170
        }
        acceleration: PointDirection {
            x: 0
            y: 185
        }
    }

    Emitter {
        id: accentEmitter
        system: fireworksSystem
        group: "rose"
        emitRate: 0
        lifeSpan: 1450
        lifeSpanVariation: 480
        size: 6
        endSize: 1
        sizeVariation: 4
        velocity: AngleDirection {
            angle: 0
            angleVariation: 360
            magnitude: 245
            magnitudeVariation: 135
        }
        acceleration: PointDirection {
            x: 0
            y: 165
        }
    }

    Emitter {
        id: sparkEmitter
        system: fireworksSystem
        group: "gold"
        emitRate: 0
        lifeSpan: 900
        lifeSpanVariation: 360
        size: 3
        endSize: 1
        sizeVariation: 2
        velocity: AngleDirection {
            angle: 0
            angleVariation: 360
            magnitude: 210
            magnitudeVariation: 130
        }
        acceleration: PointDirection {
            x: 0
            y: 230
        }
    }

    Rectangle {
        id: flashDot
        width: 90
        height: 90
        radius: 45
        color: "#ffcf26"
        opacity: 0
        scale: 0.2
        visible: root.effectMode === "fireworks"

        ParallelAnimation {
            id: flash
            NumberAnimation { target: flashDot; property: "opacity"; from: 0.62; to: 0; duration: 420; easing.type: Easing.OutQuad }
            NumberAnimation { target: flashDot; property: "scale"; from: 0.16; to: 1.55; duration: 420; easing.type: Easing.OutQuad }
        }
    }

    Timer {
        id: fireworksTimer
        interval: 430
        repeat: true
        onTriggered: root.launchFirework()
    }

    Canvas {
        id: powderCanvas
        anchors.fill: parent
        visible: root.effectMode === "powder" && root.effectRunning
        renderStrategy: Canvas.Threaded

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.clearRect(0, 0, width, height)
            if (root.effectMode !== "powder" || root.powderParticles.length === 0)
                return

            var globalTime = root.powderProgress * 3200
            for (var i = 0; i < root.powderParticles.length; ++i) {
                var p = root.powderParticles[i]
                var delay = root.particleValue(p, "delay", 0)
                var duration = root.particleValue(p, "duration", 1900)
                var local = Math.max(0, Math.min(1, (globalTime - delay) / duration))
                if (local <= 0)
                    continue

                var eased = 1 - Math.pow(1 - local, 3)
                var fade = Math.max(0, 1 - local)
                if (fade <= 0.01)
                    continue

                var size = root.particleValue(p, "size", 3)
                var x = root.particleValue(p, "x", 0) + root.particleValue(p, "dx", 300) * eased
                var y = root.particleValue(p, "y", 0) + root.particleValue(p, "dy", -120) * eased + Math.sin(eased * 7 + i * 0.31) * 26

                ctx.globalAlpha = fade
                ctx.fillStyle = root.particleValue(p, "color", "#ffffff")
                ctx.fillRect(x, y, Math.max(1.2, size * (1 - local * 0.48)), Math.max(1.2, size * (1 - local * 0.48)))
            }
            ctx.globalAlpha = 1
        }
    }

    Timer {
        id: powderClock
        interval: 16
        repeat: true
        running: root.effectMode === "powder" && root.effectRunning
        onTriggered: {
            root.powderProgress = Math.min(1, root.powderProgress + interval / 3200)
            powderCanvas.requestPaint()
            if (root.powderProgress >= 1)
                stop()
        }
    }

    Timer {
        id: finishTimer
        repeat: false
        onTriggered: root.finish()
    }
}
