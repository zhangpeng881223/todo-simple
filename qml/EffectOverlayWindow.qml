import QtQuick 2.15
import QtQuick.Window 2.15

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
    property var fireworkRockets: []
    property var fireworkSparks: []
    property double fireworkLastTick: 0
    readonly property var fireworkPalette: [
        { name: "gold", colors: ["#ffb000", "#ff6a00", "#ff2a00"] },
        { name: "crimson", colors: ["#ff2727", "#ff5b2e", "#ff9a26"] },
        { name: "rose", colors: ["#ff1f78", "#ff39c8", "#8b35ff"] },
        { name: "emerald", colors: ["#12e861", "#4cff90", "#ffb000"] },
        { name: "azure", colors: ["#168fff", "#2ff0ff", "#8b35ff"] },
        { name: "violet", colors: ["#8b35ff", "#d02cff", "#ff1f78"] },
        { name: "orange", colors: ["#ff6817", "#ffc02b", "#ff2727"] }
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
            fireworkRockets = []
            fireworkSparks = []
            fireworkLastTick = Date.now()
            Qt.callLater(function() {
                fireworksFrameTimer.start()
                fireworksTimer.start()
                launchFirework()
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
        var targetX = margin + Math.random() * Math.max(1, width - margin * 2)
        var targetY = 45 + Math.random() * Math.max(1, height * 0.58)
        var startX = targetX + (Math.random() - 0.5) * 180
        var choiceIndex = Math.floor(Math.random() * fireworkPalette.length)
        var rocket = {
            startTime: Date.now(),
            duration: 620 + Math.random() * 360,
            x0: Math.max(20, Math.min(width - 20, startX)),
            y0: height + 34,
            x1: targetX,
            y1: targetY,
            colorSet: fireworkPalette[choiceIndex].colors,
            trail: []
        }
        fireworkRockets.push(rocket)
        if (Math.random() > 0.58 && fireworkRockets.length < 8) {
            Qt.callLater(function() {
                if (root.effectMode === "fireworks")
                    root.launchFirework()
            })
        }
        fireworkCount += 1
    }

    function launchFireworkBurst(x, y, colorSet) {
        var style = Math.random()
        var count = style > 0.72 ? 190 : 132
        var ring = style > 0.55 && style <= 0.72
        var willow = style <= 0.24
        var sparks = fireworkSparks
        for (var i = 0; i < count; ++i) {
            var angle = ring ? (i / count) * Math.PI * 2 : Math.random() * Math.PI * 2
            var spread = ring ? 1 : Math.pow(Math.random(), 0.32)
            var speed = (willow ? 155 : 235) + spread * (willow ? 130 : 210)
            var color = colorSet[i % colorSet.length]
            if (Math.random() > 0.78)
                color = fireworkPalette[Math.floor(Math.random() * fireworkPalette.length)].colors[0]
            sparks.push({
                x: x,
                y: y,
                vx: Math.cos(angle) * speed * (0.72 + Math.random() * 0.36),
                vy: Math.sin(angle) * speed * (0.72 + Math.random() * 0.36),
                life: willow ? 1850 + Math.random() * 600 : 1100 + Math.random() * 650,
                maxLife: willow ? 1850 + Math.random() * 600 : 1100 + Math.random() * 650,
                color: color,
                width: willow ? 1.6 + Math.random() * 1.1 : 1.1 + Math.random() * 1.6,
                gravity: willow ? 120 + Math.random() * 90 : 70 + Math.random() * 80,
                drag: willow ? 0.988 : 0.982,
                trail: [{ x: x, y: y }]
            })
        }
        for (var j = 0; j < 34; ++j) {
            var a = Math.random() * Math.PI * 2
            var s = 45 + Math.random() * 155
            sparks.push({
                x: x,
                y: y,
                vx: Math.cos(a) * s,
                vy: Math.sin(a) * s,
                life: 520 + Math.random() * 420,
                maxLife: 680,
                color: "#ffd04a",
                width: 0.9,
                gravity: 115,
                drag: 0.97,
                trail: [{ x: x, y: y }]
            })
        }
        fireworkSparks = sparks
    }

    function finish() {
        fireworksTimer.stop()
        fireworksFrameTimer.stop()
        if (Window.window) {
            Window.window.close()
        }
    }

    Canvas {
        id: fireworksCanvas
        anchors.fill: parent
        visible: root.effectMode === "fireworks"
        renderStrategy: Canvas.Threaded

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.clearRect(0, 0, width, height)
            if (root.effectMode !== "fireworks")
                return

            ctx.globalCompositeOperation = "lighter"
            ctx.lineCap = "round"
            ctx.lineJoin = "round"

            for (var r = 0; r < root.fireworkRockets.length; ++r) {
                var rocket = root.fireworkRockets[r]
                if (rocket.trail.length < 2)
                    continue
                var rocketColor = rocket.colorSet[0]
                for (var rt = 1; rt < rocket.trail.length; ++rt) {
                    var rp0 = rocket.trail[rt - 1]
                    var rp1 = rocket.trail[rt]
                    ctx.globalAlpha = rt / rocket.trail.length * 0.8
                    ctx.strokeStyle = rocketColor
                    ctx.lineWidth = 2.2
                    ctx.beginPath()
                    ctx.moveTo(rp0.x, rp0.y)
                    ctx.lineTo(rp1.x, rp1.y)
                    ctx.stroke()
                }
            }

            for (var i = 0; i < root.fireworkSparks.length; ++i) {
                var spark = root.fireworkSparks[i]
                var fade = Math.max(0, spark.life / spark.maxLife)
                if (fade <= 0)
                    continue
                var trail = spark.trail
                for (var t = 1; t < trail.length; ++t) {
                    var p0 = trail[t - 1]
                    var p1 = trail[t]
                    var ageAlpha = t / trail.length
                    ctx.globalAlpha = Math.min(0.95, fade * ageAlpha)
                    ctx.strokeStyle = spark.color
                    ctx.lineWidth = spark.width * (0.45 + ageAlpha)
                    ctx.beginPath()
                    ctx.moveTo(p0.x, p0.y)
                    ctx.lineTo(p1.x, p1.y)
                    ctx.stroke()
                }
                ctx.globalAlpha = Math.min(0.82, fade)
                ctx.fillStyle = spark.color
                ctx.beginPath()
                ctx.arc(spark.x, spark.y, Math.max(0.8, spark.width * 0.95), 0, Math.PI * 2)
                ctx.fill()
            }

            ctx.globalAlpha = 1
            ctx.globalCompositeOperation = "source-over"
        }
    }

    Timer {
        id: fireworksTimer
        interval: 360
        repeat: true
        onTriggered: root.launchFirework()
    }

    Timer {
        id: fireworksFrameTimer
        interval: 16
        repeat: true
        running: root.effectMode === "fireworks" && root.effectRunning
        onTriggered: {
            var now = Date.now()
            var dt = Math.min(42, Math.max(8, now - root.fireworkLastTick))
            root.fireworkLastTick = now
            var dtSec = dt / 1000
            var rockets = []
            for (var i = 0; i < root.fireworkRockets.length; ++i) {
                var rocket = root.fireworkRockets[i]
                var p = Math.min(1, (now - rocket.startTime) / rocket.duration)
                var eased = 1 - Math.pow(1 - p, 3)
                var wobble = Math.sin(p * Math.PI * 5) * 8 * (1 - p)
                var x = rocket.x0 + (rocket.x1 - rocket.x0) * eased + wobble
                var y = rocket.y0 + (rocket.y1 - rocket.y0) * eased
                rocket.trail.push({ x: x, y: y })
                if (rocket.trail.length > 12)
                    rocket.trail.shift()
                if (p >= 1) {
                    root.launchFireworkBurst(rocket.x1, rocket.y1, rocket.colorSet)
                } else {
                    rockets.push(rocket)
                }
            }
            root.fireworkRockets = rockets

            var sparks = []
            for (var j = 0; j < root.fireworkSparks.length; ++j) {
                var spark = root.fireworkSparks[j]
                spark.life -= dt
                if (spark.life <= 0)
                    continue
                spark.vx *= Math.pow(spark.drag, dt / 16)
                spark.vy = spark.vy * Math.pow(spark.drag, dt / 16) + spark.gravity * dtSec
                spark.x += spark.vx * dtSec
                spark.y += spark.vy * dtSec
                spark.trail.push({ x: spark.x, y: spark.y })
                if (spark.trail.length > 14)
                    spark.trail.shift()
                if (spark.x > -80 && spark.x < width + 80 && spark.y > -80 && spark.y < height + 100)
                    sparks.push(spark)
            }
            root.fireworkSparks = sparks
            fireworksCanvas.requestPaint()
        }
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
