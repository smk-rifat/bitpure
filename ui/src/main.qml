import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Audioplayer 1.0

ApplicationWindow {
    id: root
    visible: true
    width: 1040
    height: 680
    minimumWidth: 840
    minimumHeight: 560
    title: "BitPure — " + localTheme.currentTheme.toUpperCase()

    Theme {
        id: localTheme
    }

    Backend {
        id: localBackend
    }

    property string currentTab: "queue" // queue, albums, artists, dopamine, settings
    property int currentSortIndex: 6
    property string activeSearchQuery: ""

    color: localTheme.darkBackground

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        // =====================================================================
        // 1. TOP HEADER BAR: [State & Time] | [Title & Artist] | [Volume & Mode]
        // =====================================================================
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 54
            color: localTheme.surface
            border.color: localTheme.border
            border.width: 1
            radius: localTheme.radius

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 16

                // LEFT: [Playing/Stopped] + 0:00 / 0:00
                ColumnLayout {
                    Layout.preferredWidth: 140
                    spacing: 2

                    RowLayout {
                        spacing: 6
                        Text {
                            text: localBackend.isPlaying ? "[Playing]" : "[Stopped]"
                            color: localBackend.isPlaying ? localTheme.green : localTheme.orange
                            font.bold: true
                            font.pixelSize: 12
                            font.family: "monospace"
                        }

                        // Play/Pause clickable icon
                        Rectangle {
                            width: 18
                            height: 18
                            radius: localTheme.radius
                            color: "transparent"
                            border.color: localTheme.border
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: localBackend.isPlaying ? "⏸" : "▶"
                                color: localTheme.foreground
                                font.pixelSize: 9
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (localBackend.isPlaying) {
                                        localBackend.pause();
                                    } else if (localBackend.tracks.length > 0) {
                                        var trk = localBackend.tracks[0];
                                        localBackend.playTrack(trk.file_path, trk.title, trk.track_artist);
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        text: (localBackend.positionStr.length > 0 ? localBackend.positionStr : "0:00") + " / " + (localBackend.durationStr.length > 0 ? localBackend.durationStr : "0:00")
                        color: localTheme.foreground
                        font.pixelSize: 11
                        font.family: "monospace"
                    }
                }

                // CENTER: Now Playing Title & Artist
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 2

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: localBackend.nowPlayingTitle.length > 0 ? localBackend.nowPlayingTitle : "No Song"
                        color: localTheme.foreground
                        font.bold: true
                        font.pixelSize: 13
                        font.family: "monospace"
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: localBackend.nowPlayingArtist.length > 0 ? (localBackend.nowPlayingArtist + " — " + (localBackend.isBitPerfect ? "[Bit-Perfect 0dB]" : "[Audited DSP]")) : "Unknown — Unknown Album"
                        color: localTheme.yellow
                        font.pixelSize: 11
                        font.family: "monospace"
                        elide: Text.ElideRight
                    }
                }

                // RIGHT: Interactive Volume Bar & [zxcv] shortcuts
                ColumnLayout {
                    Layout.preferredWidth: 200
                    Layout.alignment: Qt.AlignRight
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        // Speaker Icon
                        Text {
                            text: localBackend.isBitPerfect ? "🔊" : (localBackend.volume === 0 ? "🔇" : "🔉")
                            color: localBackend.isBitPerfect ? localTheme.green : localTheme.accent
                            font.pixelSize: 12

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (localBackend.isBitPerfect) {
                                        localBackend.isBitPerfect = false;
                                    } else {
                                        localBackend.volume = (localBackend.volume === 0 ? 0.40 : 0.0);
                                    }
                                }
                                onWheel: (wheel) => {
                                    var step = (wheel.angleDelta.y > 0 ? 0.04 : -0.04);
                                    localBackend.volume = Math.max(0.0, Math.min(1.0, localBackend.volume + step));
                                }
                            }
                        }

                        // Slidable Track
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 18

                            // Horizontal Line Track
                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width
                                height: 2
                                color: localTheme.border

                                Rectangle {
                                    height: parent.height
                                    width: parent.width * localBackend.volume
                                    color: localBackend.isBitPerfect ? localTheme.green : localTheme.accent
                                }
                            }

                            // Knob
                            Rectangle {
                                y: parent.height / 2 - 4
                                x: Math.max(0, Math.min(parent.width - 8, (parent.width * localBackend.volume) - 4))
                                width: 8
                                height: 8
                                radius: 4
                                color: localBackend.isBitPerfect ? localTheme.green : localTheme.accent
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: (mouse) => {
                                    localBackend.volume = Math.max(0.0, Math.min(1.0, mouse.x / width));
                                }
                                onPositionChanged: (mouse) => {
                                    if (pressed) {
                                        localBackend.volume = Math.max(0.0, Math.min(1.0, mouse.x / width));
                                    }
                                }
                                onWheel: (wheel) => {
                                    var step = (wheel.angleDelta.y > 0 ? 0.04 : -0.04);
                                    localBackend.volume = Math.max(0.0, Math.min(1.0, localBackend.volume + step));
                                }
                            }
                        }

                        // Volume Percentage
                        Text {
                            text: localBackend.isBitPerfect ? "●100%" : (Math.round(localBackend.volume * 100) + "%")
                            color: localBackend.isBitPerfect ? localTheme.green : localTheme.accent
                            font.bold: true
                            font.pixelSize: 11
                            font.family: "monospace"
                        }
                    }

                    // Pure Mode Toggle / Shortcuts Readout
                    RowLayout {
                        Layout.alignment: Qt.AlignRight
                        spacing: 6

                        Text {
                            text: localBackend.isBitPerfect ? "[PURE 0dB LINE-OUT]" : "[DSP ACTIVE]"
                            color: localBackend.isBitPerfect ? localTheme.green : localTheme.orange
                            font.pixelSize: 10
                            font.family: "monospace"

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: localBackend.isBitPerfect = !localBackend.isBitPerfect
                                onWheel: (wheel) => {
                                    var step = (wheel.angleDelta.y > 0 ? 0.04 : -0.04);
                                    localBackend.volume = Math.max(0.0, Math.min(1.0, localBackend.volume + step));
                                }
                            }
                        }

                        Text {
                            text: "[zxcv]"
                            color: localTheme.muted
                            font.pixelSize: 10
                            font.family: "monospace"
                        }
                    }
                }
            }
        }

        // =====================================================================
        // 1.5 TRACK PROGRESS & SEEK BAR (Click or drag anywhere to seek)
        // =====================================================================
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            color: localTheme.surface
            border.color: localTheme.border
            border.width: 1
            radius: localTheme.radius

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 12

                Text {
                    text: localBackend.positionStr.length > 0 ? localBackend.positionStr : "0:00"
                    color: localBackend.isPlaying ? localTheme.green : localTheme.foreground
                    font.bold: true
                    font.pixelSize: 11
                    font.family: "monospace"
                }

                Item {
                    id: seekAreaItem
                    Layout.fillWidth: true
                    Layout.preferredHeight: parent.height

                    // Background Track
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width
                        height: 4
                        radius: 2
                        color: localTheme.darkBackground

                        // Active Progress Fill
                        Rectangle {
                            height: parent.height
                            width: Math.max(0, Math.min(parent.width, parent.width * localBackend.progress))
                            radius: 2
                            color: localBackend.isBitPerfect ? localTheme.green : localTheme.accent
                        }
                    }

                    // Draggable Playhead Knob
                    Rectangle {
                        y: parent.height / 2 - 5
                        x: Math.max(0, Math.min(parent.width - 10, (parent.width * localBackend.progress) - 5))
                        width: 10
                        height: 10
                        radius: 5
                        color: localBackend.isBitPerfect ? localTheme.green : localTheme.accent
                        border.color: localTheme.surface
                        border.width: 1
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: (mouse) => {
                            var frac = Math.max(0.0, Math.min(1.0, mouse.x / width));
                            localBackend.seekFraction(frac);
                        }
                        onPositionChanged: (mouse) => {
                            if (pressed) {
                                var frac = Math.max(0.0, Math.min(1.0, mouse.x / width));
                                localBackend.seekFraction(frac);
                            }
                        }
                    }
                }

                Text {
                    text: localBackend.durationStr.length > 0 ? localBackend.durationStr : "0:00"
                    color: localTheme.muted
                    font.bold: true
                    font.pixelSize: 11
                    font.family: "monospace"
                }
            }
        }

        // =====================================================================
        // 2. HORIZONTAL TAB BAR: Queue | Directories | Artists | Albums | Settings
        // =====================================================================
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: [
                    { id: "queue", label: "Queue" },
                    { id: "albums", label: "Albums" },
                    { id: "artists", label: "Artists" },
                    { id: "dopamine", label: "Dopamine Hits" },
                    { id: "all", label: "All Songs" },
                    { id: "settings", label: "Settings" }
                ]

                Rectangle {
                    Layout.preferredHeight: 26
                    Layout.preferredWidth: tabText.implicitWidth + 24
                    radius: localTheme.radius
                    color: currentTab === modelData.id ? localTheme.accent : (tabMouse.containsMouse ? localTheme.surfaceLighter : "transparent")
                    border.color: currentTab === modelData.id ? localTheme.accent : localTheme.border
                    border.width: 1

                    Text {
                        id: tabText
                        anchors.centerIn: parent
                        text: modelData.label
                        color: currentTab === modelData.id ? localTheme.darkBackground : localTheme.foreground
                        font.bold: currentTab === modelData.id
                        font.pixelSize: 11
                        font.family: "monospace"
                    }

                    MouseArea {
                        id: tabMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            currentTab = modelData.id;
                            if (modelData.id === "dopamine") {
                                localBackend.setSortCriteria(6);
                            } else if (modelData.id === "all") {
                                localBackend.setSortCriteria(0);
                            }
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Theme Switcher Quick Badge
            Rectangle {
                Layout.preferredHeight: 24
                Layout.preferredWidth: themeLabel.implicitWidth + 16
                radius: localTheme.radius
                color: localTheme.surface
                border.color: localTheme.border
                border.width: 1

                Text {
                    id: themeLabel
                    anchors.centerIn: parent
                    text: "🎨 " + localTheme.currentTheme
                    color: localTheme.accent
                    font.bold: true
                    font.pixelSize: 10
                    font.family: "monospace"
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var themes = localTheme.availableThemes;
                        var idx = themes.indexOf(localTheme.currentTheme);
                        var nextIdx = (idx + 1) % themes.length;
                        localTheme.currentTheme = themes[nextIdx];
                    }
                }
            }
        }

        // =====================================================================
        // 3. MAIN DUAL-PANE BODY: Left (Cover & Telemetry) + Right (Content)
        // =====================================================================
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            // -----------------------------------------------------------------
            // LEFT PANE: Album Art Box + Lyrics / Telemetry Box
            // -----------------------------------------------------------------
            Rectangle {
                Layout.preferredWidth: 310
                Layout.fillHeight: true
                color: localTheme.surface
                border.color: localTheme.border
                border.width: 1
                radius: localTheme.radius

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    // ALBUM ARTWORK CONTAINER
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 260
                        color: localTheme.darkBackground
                        border.color: localTheme.border
                        border.width: 1
                        radius: localTheme.radius

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "♫"
                                color: localTheme.foreground
                                font.pixelSize: 64
                                font.bold: true
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: localBackend.nowPlayingTitle.length > 0 ? localBackend.nowPlayingTitle : "Audiophile Lossless"
                                color: localTheme.foreground
                                font.bold: true
                                font.pixelSize: 11
                                font.family: "monospace"
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: localBackend.formatBadge
                                color: localTheme.accent
                                font.pixelSize: 10
                                font.family: "monospace"
                            }
                        }
                    }

                    // SECTION HEADER: ── Lyrics & Signal Path ──
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Rectangle { Layout.fillWidth: true; height: 1; color: localTheme.border }
                        Text {
                            text: "── Hardware & Signal Chain ──"
                            color: localTheme.muted
                            font.pixelSize: 10
                            font.family: "monospace"
                        }
                        Rectangle { Layout.fillWidth: true; height: 1; color: localTheme.border }
                    }

                    // TELEMETRY & SIGNAL PATH READOUT
                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        ColumnLayout {
                            width: parent.width
                            spacing: 8

                            // Mode Badge
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 32
                                color: localBackend.isBitPerfect ? "#212b26" : localTheme.darkBackground
                                border.color: localBackend.isBitPerfect ? localTheme.green : localTheme.border
                                border.width: 1
                                radius: localTheme.radius

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 6
                                    Text {
                                        text: localBackend.isBitPerfect ? "● PURE BIT-PERFECT DIRECT" : "○ AUDITED DSP MODE"
                                        color: localBackend.isBitPerfect ? localTheme.green : localTheme.yellow
                                        font.bold: true
                                        font.pixelSize: 10
                                        font.family: "monospace"
                                    }
                                }
                            }

                            // Device info
                            Text {
                                text: "HARDWARE ENDPOINT:"
                                color: localTheme.muted
                                font.bold: true
                                font.pixelSize: 9
                                font.family: "monospace"
                            }
                            Text {
                                text: localBackend.activeDeviceId
                                color: localTheme.accent
                                font.pixelSize: 10
                                font.family: "monospace"
                                elide: Text.ElideRight
                            }

                            // Signal Info
                            Text {
                                text: "SIGNAL PATH STATUS:"
                                color: localTheme.muted
                                font.bold: true
                                font.pixelSize: 9
                                font.family: "monospace"
                            }
                            Text {
                                text: localBackend.signalPathInfo
                                color: localBackend.isBitPerfect ? localTheme.green : localTheme.yellow
                                font.pixelSize: 10
                                font.family: "monospace"
                                wrapMode: Text.Wrap
                            }

                            // High-Res Specs
                            Text {
                                text: "STREAM SPECIFICATION:"
                                color: localTheme.muted
                                font.bold: true
                                font.pixelSize: 9
                                font.family: "monospace"
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 46
                                color: localTheme.darkBackground
                                border.color: localTheme.border
                                border.width: 1
                                radius: localTheme.radius

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    spacing: 2
                                    Text {
                                        text: localBackend.formatBadge
                                        color: localTheme.foreground
                                        font.bold: true
                                        font.pixelSize: 10
                                        font.family: "monospace"
                                    }
                                    Text {
                                        text: "Bitstream: Uncompressed PCM / ALSA Direct"
                                        color: localTheme.muted
                                        font.pixelSize: 9
                                        font.family: "monospace"
                                    }
                                }
                            }

                            // EQ Status Note
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 32
                                color: "transparent"
                                border.color: localTheme.border
                                border.width: 1
                                radius: localTheme.radius

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    spacing: 6
                                    Text {
                                        text: "🎚️"
                                        font.pixelSize: 11
                                    }
                                    Text {
                                        text: localBackend.isBitPerfect ? "EQ Bypassed (Settings > EQ)" : "DSP Active (Settings > EQ)"
                                        color: localTheme.muted
                                        font.pixelSize: 9
                                        font.family: "monospace"
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: currentTab = "settings"
                                }
                            }
                        }
                    }
                }
            }

            // -----------------------------------------------------------------
            // RIGHT PANE: Track Table / Album Grid / Settings
            // -----------------------------------------------------------------
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: localTheme.surface
                border.color: localTheme.border
                border.width: 1
                radius: localTheme.radius

                // A. TRACK TABLE VIEW (Used for Queue, Dopamine Hits, All Songs)
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6
                    visible: currentTab === "queue" || currentTab === "dopamine" || currentTab === "all" || currentTab === "artists"

                    // TABLE HEADER BAR
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 24
                        color: localTheme.darkBackground
                        border.color: localTheme.border
                        border.width: 1
                        radius: localTheme.radius

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10

                            Text {
                                Layout.preferredWidth: 200
                                text: "Artist"
                                color: localTheme.muted
                                font.bold: true
                                font.pixelSize: 11
                                font.family: "monospace"
                            }
                            Text {
                                Layout.fillWidth: true
                                text: "Title"
                                color: localTheme.muted
                                font.bold: true
                                font.pixelSize: 11
                                font.family: "monospace"
                            }
                            Text {
                                Layout.preferredWidth: 200
                                text: "Album"
                                color: localTheme.muted
                                font.bold: true
                                font.pixelSize: 11
                                font.family: "monospace"
                            }
                            Text {
                                Layout.preferredWidth: 70
                                horizontalAlignment: Text.AlignRight
                                text: "Duration"
                                color: localTheme.muted
                                font.bold: true
                                font.pixelSize: 11
                                font.family: "monospace"
                            }
                        }
                    }

                    // TRACKS LIST
                    ListView {
                        id: trackTable
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: localBackend.tracks

                        delegate: Rectangle {
                            width: trackTable.width
                            height: 28
                            radius: localTheme.radius
                            color: isCurrentTrack ? localTheme.selection : (rowMouse.containsMouse ? localTheme.surfaceLighter : "transparent")

                            property bool isCurrentTrack: localBackend.isPlaying && localBackend.nowPlayingTitle === modelData.title

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10

                                Text {
                                    Layout.preferredWidth: 200
                                    text: modelData.track_artist
                                    color: isCurrentTrack ? localTheme.accent : localTheme.foreground
                                    font.pixelSize: 11
                                    font.family: "monospace"
                                    elide: Text.ElideRight
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Text {
                                        visible: isCurrentTrack
                                        text: "▶"
                                        color: localTheme.green
                                        font.pixelSize: 10
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.title
                                        color: isCurrentTrack ? localTheme.green : localTheme.foreground
                                        font.bold: isCurrentTrack
                                        font.pixelSize: 11
                                        font.family: "monospace"
                                        elide: Text.ElideRight
                                    }
                                }

                                Text {
                                    Layout.preferredWidth: 200
                                    text: "Lossless FLAC"
                                    color: localTheme.muted
                                    font.pixelSize: 11
                                    font.family: "monospace"
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.preferredWidth: 70
                                    horizontalAlignment: Text.AlignRight
                                    text: formatDuration(modelData.duration_ms)
                                    color: localTheme.muted
                                    font.pixelSize: 11
                                    font.family: "monospace"
                                }
                            }

                            MouseArea {
                                id: rowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: localBackend.playTrack(modelData.file_path, modelData.title, modelData.track_artist)
                            }
                        }
                    }
                }

                // B. ALBUM GRID VIEW
                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 14
                    visible: currentTab === "albums"
                    clip: true

                    GridView {
                        width: parent.width
                        cellWidth: 180
                        cellHeight: 180
                        model: localBackend.albums

                        delegate: Rectangle {
                            width: 164
                            height: 164
                            radius: localTheme.radius
                            color: albMouse.containsMouse ? localTheme.surfaceLighter : localTheme.darkBackground
                            border.color: localTheme.border
                            border.width: 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 6

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 90
                                    color: localTheme.surface
                                    border.color: localTheme.border
                                    border.width: 1
                                    radius: localTheme.radius

                                    Text {
                                        anchors.centerIn: parent
                                        text: "💿"
                                        font.pixelSize: 32
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.title
                                    color: localTheme.foreground
                                    font.bold: true
                                    font.pixelSize: 11
                                    font.family: "monospace"
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.album_artist
                                    color: localTheme.yellow
                                    font.pixelSize: 10
                                    font.family: "monospace"
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                id: albMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: currentTab = "queue"
                            }
                        }
                    }
                }

                // C. SETTINGS VIEW (Omarchy Distro Grade Configuration Suite)
                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 18
                    visible: currentTab === "settings"
                    clip: true

                    ColumnLayout {
                        width: parent.width - 24
                        spacing: 16

                        // Header Bar
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            ColumnLayout {
                                spacing: 3
                                Text {
                                    text: "SYSTEM & AUDIO ARCHITECTURE CONFIGURATION"
                                    color: localTheme.foreground
                                    font.bold: true
                                    font.pixelSize: 13
                                    font.family: "monospace"
                                }
                                Text {
                                    text: "Audiophile bit-perfect signal path, hardware DSP faders, library scanner & Omarchy desktop integration"
                                    color: localTheme.muted
                                    font.pixelSize: 10
                                    font.family: "monospace"
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                Layout.preferredHeight: 22
                                Layout.preferredWidth: archBadge.implicitWidth + 14
                                radius: localTheme.radius
                                color: localTheme.darkBackground
                                border.color: localTheme.border
                                border.width: 1

                                Text {
                                    id: archBadge
                                    anchors.centerIn: parent
                                    text: "BitPure v1.0.0 — Arch Linux / Wayland"
                                    color: localTheme.accent
                                    font.pixelSize: 9
                                    font.family: "monospace"
                                }
                            }
                        }

                        // =====================================================
                        // SECTION 1: 10-BAND GRAPHIC EQUALIZER & DSP
                        // =====================================================
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: eqCol.implicitHeight + 24
                            color: localTheme.surface
                            border.color: localTheme.border
                            border.width: 1
                            radius: localTheme.radius

                            ColumnLayout {
                                id: eqCol
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 12

                                // Section Title & State Badge
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: "[ 01 // 10-BAND GRAPHIC EQUALIZER & DSP ]"
                                        color: localTheme.accent
                                        font.bold: true
                                        font.pixelSize: 11
                                        font.family: "monospace"
                                    }

                                    Item { Layout.fillWidth: true }

                                    Rectangle {
                                        Layout.preferredHeight: 20
                                        Layout.preferredWidth: eqStatusBadge.implicitWidth + 12
                                        radius: localTheme.radius
                                        color: localBackend.isBitPerfect ? "#212b26" : "#2d281e"
                                        border.color: localBackend.isBitPerfect ? localTheme.green : localTheme.yellow
                                        border.width: 1

                                        Text {
                                            id: eqStatusBadge
                                            anchors.centerIn: parent
                                            text: localBackend.isBitPerfect ? "● BYPASSED (PURE 0dB DIRECT)" : "○ DSP ACTIVE (10 BIQUAD FILTERS)"
                                            color: localBackend.isBitPerfect ? localTheme.green : localTheme.yellow
                                            font.bold: true
                                            font.pixelSize: 9
                                            font.family: "monospace"
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: "Direct hardware passthrough (Pure 0dB) bypasses DSP for zero digital distortion. Selecting a preset or adjusting faders automatically switches to Audited DSP Mode."
                                    color: localTheme.muted
                                    font.pixelSize: 10
                                    font.family: "monospace"
                                    wrapMode: Text.Wrap
                                }

                                // Presets Bar
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Text {
                                        text: "PRESETS:"
                                        color: localTheme.foreground
                                        font.bold: true
                                        font.pixelSize: 10
                                        font.family: "monospace"
                                    }

                                    Repeater {
                                        model: [
                                            { id: 0, label: "Flat (0.0 dB)" },
                                            { id: 1, label: "Balanced" },
                                            { id: 2, label: "Bass Boost" },
                                            { id: 3, label: "Warm Vocal" },
                                            { id: 4, label: "Treble Clean" }
                                        ]

                                        Rectangle {
                                            Layout.preferredHeight: 24
                                            Layout.preferredWidth: pText.implicitWidth + 16
                                            radius: localTheme.radius
                                            color: localBackend.activeEqPreset === modelData.id ? localTheme.accent : (pMouse.containsMouse ? localTheme.surfaceLighter : localTheme.darkBackground)
                                            border.color: localBackend.activeEqPreset === modelData.id ? localTheme.accent : localTheme.border
                                            border.width: 1

                                            Text {
                                                id: pText
                                                anchors.centerIn: parent
                                                text: modelData.label
                                                color: localBackend.activeEqPreset === modelData.id ? localTheme.darkBackground : localTheme.foreground
                                                font.bold: localBackend.activeEqPreset === modelData.id
                                                font.pixelSize: 10
                                                font.family: "monospace"
                                            }

                                            MouseArea {
                                                id: pMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (localBackend.isBitPerfect) {
                                                        localBackend.isBitPerfect = false;
                                                    }
                                                    localBackend.activeEqPreset = modelData.id;
                                                }
                                            }
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    // Reset Button
                                    Rectangle {
                                        Layout.preferredHeight: 24
                                        Layout.preferredWidth: rText.implicitWidth + 14
                                        radius: localTheme.radius
                                        color: "transparent"
                                        border.color: localTheme.border
                                        border.width: 1

                                        Text {
                                            id: rText
                                            anchors.centerIn: parent
                                            text: "↺ Reset Flat"
                                            color: rMouse.containsMouse ? localTheme.foreground : localTheme.muted
                                            font.pixelSize: 10
                                            font.family: "monospace"
                                        }

                                        MouseArea {
                                            id: rMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (localBackend.isBitPerfect) {
                                                    localBackend.isBitPerfect = false;
                                                }
                                                localBackend.activeEqPreset = 0;
                                            }
                                        }
                                    }
                                }

                                // 10-Band Graphic Visual Faders
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 140
                                    color: localTheme.darkBackground
                                    border.color: localTheme.border
                                    border.width: 1
                                    radius: localTheme.radius

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 8

                                        Repeater {
                                            model: [
                                                { band: 0, freq: "31 Hz" },
                                                { band: 1, freq: "62 Hz" },
                                                { band: 2, freq: "125 Hz" },
                                                { band: 3, freq: "250 Hz" },
                                                { band: 4, freq: "500 Hz" },
                                                { band: 5, freq: "1 kHz" },
                                                { band: 6, freq: "2 kHz" },
                                                { band: 7, freq: "4 kHz" },
                                                { band: 8, freq: "8 kHz" },
                                                { band: 9, freq: "16 kHz" }
                                            ]

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                Layout.fillHeight: true
                                                spacing: 4

                                                property real bandGain: (localBackend.eqGains.length > modelData.band) ? Number(localBackend.eqGains[modelData.band]) : 0.0

                                                // Gain Readout
                                                Text {
                                                    Layout.alignment: Qt.AlignHCenter
                                                    text: (bandGain > 0 ? "+" : "") + bandGain.toFixed(1)
                                                    color: Math.abs(bandGain) > 0.01 ? localTheme.accent : localTheme.muted
                                                    font.bold: Math.abs(bandGain) > 0.01
                                                    font.pixelSize: 9
                                                    font.family: "monospace"
                                                }

                                                // Vertical Track & Knob
                                                Item {
                                                    id: faderTrack
                                                    Layout.fillWidth: true
                                                    Layout.fillHeight: true

                                                    // Center 0 dB zero line
                                                    Rectangle {
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        width: parent.width
                                                        height: 1
                                                        color: localTheme.border
                                                    }

                                                    // Vertical Center Slot
                                                    Rectangle {
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        width: 3
                                                        height: parent.height
                                                        radius: 1
                                                        color: localTheme.surface

                                                        // Active Fill from Center
                                                        Rectangle {
                                                            anchors.horizontalCenter: parent.horizontalCenter
                                                            y: bandGain >= 0 ? parent.height / 2 - (bandGain / 12.0) * (parent.height / 2) : parent.height / 2
                                                            height: Math.abs(bandGain / 12.0) * (parent.height / 2)
                                                            width: 3
                                                            color: localTheme.accent
                                                        }
                                                    }

                                                    // Draggable Knob
                                                    Rectangle {
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        y: Math.max(0, Math.min(parent.height - 12, (parent.height / 2) - ((bandGain / 12.0) * (parent.height / 2)) - 6))
                                                        width: 16
                                                        height: 12
                                                        radius: 2
                                                        color: faderMouse.containsMouse ? localTheme.accent : localTheme.surfaceLighter
                                                        border.color: localTheme.accent
                                                        border.width: 1

                                                        Rectangle {
                                                            anchors.centerIn: parent
                                                            width: 8
                                                            height: 1
                                                            color: faderMouse.containsMouse ? localTheme.darkBackground : localTheme.foreground
                                                        }
                                                    }

                                                    MouseArea {
                                                        id: faderMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: (mouse) => {
                                                            if (localBackend.isBitPerfect) localBackend.isBitPerfect = false;
                                                            var normalized = 1.0 - (mouse.y / height); // 0.0 at bottom, 1.0 at top
                                                            var db = (normalized * 24.0) - 12.0;
                                                            localBackend.setEqBand(modelData.band, Math.max(-12.0, Math.min(12.0, db)));
                                                        }
                                                        onPositionChanged: (mouse) => {
                                                            if (pressed) {
                                                                if (localBackend.isBitPerfect) localBackend.isBitPerfect = false;
                                                                var normalized = 1.0 - (mouse.y / height);
                                                                var db = (normalized * 24.0) - 12.0;
                                                                localBackend.setEqBand(modelData.band, Math.max(-12.0, Math.min(12.0, db)));
                                                            }
                                                        }
                                                        onWheel: (wheel) => {
                                                            if (localBackend.isBitPerfect) localBackend.isBitPerfect = false;
                                                            var step = (wheel.angleDelta.y > 0 ? 0.5 : -0.5);
                                                            localBackend.setEqBand(modelData.band, Math.max(-12.0, Math.min(12.0, bandGain + step)));
                                                        }
                                                    }
                                                }

                                                // Frequency Label
                                                Text {
                                                    Layout.alignment: Qt.AlignHCenter
                                                    text: modelData.freq
                                                    color: localTheme.foreground
                                                    font.pixelSize: 9
                                                    font.family: "monospace"
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // =====================================================
                        // SECTION 2: AUDIO HARDWARE ROUTING & PURE MODE
                        // =====================================================
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: devCol.implicitHeight + 24
                            color: localTheme.surface
                            border.color: localTheme.border
                            border.width: 1
                            radius: localTheme.radius

                            ColumnLayout {
                                id: devCol
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 10

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: "[ 02 // AUDIO HARDWARE ENDPOINTS & PURE MODE ]"
                                        color: localTheme.accent
                                        font.bold: true
                                        font.pixelSize: 11
                                        font.family: "monospace"
                                    }
                                    Item { Layout.fillWidth: true }
                                }

                                // Bit-Perfect Pure Mode Card
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 38
                                    radius: localTheme.radius
                                    color: localBackend.isBitPerfect ? "#212b26" : localTheme.darkBackground
                                    border.color: localBackend.isBitPerfect ? localTheme.green : localTheme.border
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 10

                                        Text {
                                            text: localBackend.isBitPerfect ? "🔒 PURE BIT-PERFECT LINE-OUT (0 dB DIRECT)" : "🔓 SOFTWARE DSP AUDIO PATH ACTIVE"
                                            color: localBackend.isBitPerfect ? localTheme.green : localTheme.yellow
                                            font.bold: true
                                            font.pixelSize: 11
                                            font.family: "monospace"
                                        }

                                        Item { Layout.fillWidth: true }

                                        Text {
                                            text: localBackend.isBitPerfect ? "Bypasses all mixers & DSP" : "Volume & EQ enabled"
                                            color: localTheme.muted
                                            font.pixelSize: 10
                                            font.family: "monospace"
                                        }

                                        Rectangle {
                                            Layout.preferredHeight: 22
                                            Layout.preferredWidth: 70
                                            radius: localTheme.radius
                                            color: localBackend.isBitPerfect ? localTheme.green : localTheme.surfaceLighter

                                            Text {
                                                anchors.centerIn: parent
                                                text: localBackend.isBitPerfect ? "Active" : "Enable"
                                                color: localBackend.isBitPerfect ? localTheme.darkBackground : localTheme.foreground
                                                font.bold: true
                                                font.pixelSize: 10
                                                font.family: "monospace"
                                            }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: localBackend.isBitPerfect = !localBackend.isBitPerfect
                                    }
                                }

                                // Detected Devices
                                Text {
                                    text: "DETECTED HARDWARE OUTPUTS:"
                                    color: localTheme.muted
                                    font.bold: true
                                    font.pixelSize: 9
                                    font.family: "monospace"
                                }

                                Repeater {
                                    model: localBackend.devices
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 36
                                        color: localBackend.activeDeviceId === modelData.id ? localTheme.selection : localTheme.darkBackground
                                        border.color: localBackend.activeDeviceId === modelData.id ? localTheme.accent : localTheme.border
                                        border.width: 1
                                        radius: localTheme.radius

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 10
                                            spacing: 8

                                            Text {
                                                text: localBackend.activeDeviceId === modelData.id ? "●" : "○"
                                                color: localBackend.activeDeviceId === modelData.id ? localTheme.green : localTheme.muted
                                                font.pixelSize: 12
                                            }

                                            Text {
                                                text: modelData.name
                                                color: localBackend.activeDeviceId === modelData.id ? localTheme.accent : localTheme.foreground
                                                font.bold: localBackend.activeDeviceId === modelData.id
                                                font.pixelSize: 11
                                                font.family: "monospace"
                                            }

                                            Item { Layout.fillWidth: true }

                                            Text {
                                                text: modelData.id
                                                color: localTheme.muted
                                                font.pixelSize: 10
                                                font.family: "monospace"
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: localBackend.activeDeviceId = modelData.id
                                        }
                                    }
                                }
                            }
                        }

                        // =====================================================
                        // SECTION 3: MUSIC STORAGE & FAST INDEXER
                        // =====================================================
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: libCol.implicitHeight + 24
                            color: localTheme.surface
                            border.color: localTheme.border
                            border.width: 1
                            radius: localTheme.radius

                            ColumnLayout {
                                id: libCol
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 10

                                Text {
                                    text: "[ 03 // MUSIC LIBRARY & INOTIFY MONITOR ]"
                                    color: localTheme.accent
                                    font.bold: true
                                    font.pixelSize: 11
                                    font.family: "monospace"
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 32
                                        color: localTheme.darkBackground
                                        border.color: localTheme.border
                                        border.width: 1
                                        radius: localTheme.radius

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            spacing: 8

                                            Text {
                                                text: "DIR ❯"
                                                color: localTheme.yellow
                                                font.bold: true
                                                font.pixelSize: 11
                                                font.family: "monospace"
                                            }

                                            TextInput {
                                                id: folderInput
                                                Layout.fillWidth: true
                                                text: localBackend.musicFolder
                                                color: localTheme.foreground
                                                font.pixelSize: 11
                                                font.family: "monospace"
                                            }
                                        }
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: 110
                                        Layout.preferredHeight: 32
                                        color: scanMouse.containsMouse ? localTheme.green : localTheme.accent
                                        radius: localTheme.radius

                                        Text {
                                            anchors.centerIn: parent
                                            text: "↻ Rescan Now"
                                            color: localTheme.darkBackground
                                            font.bold: true
                                            font.pixelSize: 10
                                            font.family: "monospace"
                                        }

                                        MouseArea {
                                            id: scanMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: localBackend.setMusicFolder(folderInput.text)
                                        }
                                    }
                                }

                                // Telemetry metrics
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 28
                                        color: localTheme.darkBackground
                                        border.color: localTheme.border
                                        border.width: 1
                                        radius: localTheme.radius

                                        Text {
                                            anchors.centerIn: parent
                                            text: "Library: " + localBackend.tracks.length + " lossless FLAC tracks indexed"
                                            color: localTheme.foreground
                                            font.pixelSize: 10
                                            font.family: "monospace"
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 28
                                        color: localTheme.darkBackground
                                        border.color: localTheme.border
                                        border.width: 1
                                        radius: localTheme.radius

                                        Text {
                                            anchors.centerIn: parent
                                            text: "Monitoring: inotify active (Zero-polling)"
                                            color: localTheme.muted
                                            font.pixelSize: 10
                                            font.family: "monospace"
                                        }
                                    }
                                }
                            }
                        }

                        // =====================================================
                        // SECTION 4: OMARCHY DESKTOP PALETTES
                        // =====================================================
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: thCol.implicitHeight + 24
                            color: localTheme.surface
                            border.color: localTheme.border
                            border.width: 1
                            radius: localTheme.radius

                            ColumnLayout {
                                id: thCol
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 10

                                Text {
                                    text: "[ 04 // OMARCHY DESKTOP THEMES & PALETTES ]"
                                    color: localTheme.accent
                                    font.bold: true
                                    font.pixelSize: 11
                                    font.family: "monospace"
                                }

                                Text {
                                    text: "Curated Neovim and terminal color palettes with live desktop theme switching."
                                    color: localTheme.muted
                                    font.pixelSize: 10
                                    font.family: "monospace"
                                }

                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Repeater {
                                        model: [
                                            { id: "everforest", name: "Everforest", bg: "#232a2e", accent: "#7fbbb3", sub: "#a7c080" },
                                            { id: "gruvbox", name: "Gruvbox", bg: "#1d2021", accent: "#7daea3", sub: "#d8a657" },
                                            { id: "nord", name: "Nord", bg: "#242933", accent: "#88c0d0", sub: "#a3be8c" },
                                            { id: "tokyonight", name: "Tokyo Night", bg: "#1a1b26", accent: "#7aa2f7", sub: "#9ece6a" },
                                            { id: "kanagawa", name: "Kanagawa", bg: "#16161d", accent: "#7e9cd8", sub: "#76946a" },
                                            { id: "catppuccin", name: "Catppuccin", bg: "#181825", accent: "#89b4fa", sub: "#a6e3a1" },
                                            { id: "rose-pine", name: "Rose Pine", bg: "#191724", accent: "#9ccfd8", sub: "#ebbcba" }
                                        ]

                                        Rectangle {
                                            width: 132
                                            height: 38
                                            radius: localTheme.radius
                                            color: localTheme.currentTheme === modelData.id ? localTheme.selection : localTheme.darkBackground
                                            border.color: localTheme.currentTheme === modelData.id ? localTheme.accent : localTheme.border
                                            border.width: 1

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.margins: 8
                                                spacing: 6

                                                // Mini color chips
                                                Row {
                                                    spacing: 3
                                                    Rectangle { width: 8; height: 8; radius: 4; color: modelData.accent }
                                                    Rectangle { width: 8; height: 8; radius: 4; color: modelData.sub }
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: modelData.name
                                                    color: localTheme.currentTheme === modelData.id ? localTheme.accent : localTheme.foreground
                                                    font.bold: localTheme.currentTheme === modelData.id
                                                    font.pixelSize: 10
                                                    font.family: "monospace"
                                                    elide: Text.ElideRight
                                                }

                                                Text {
                                                    text: "✓"
                                                    visible: localTheme.currentTheme === modelData.id
                                                    color: localTheme.accent
                                                    font.pixelSize: 10
                                                }
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: localTheme.currentTheme = modelData.id
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // =====================================================
                        // SECTION 5: VIM & HYPRLAND SHORTCUTS
                        // =====================================================
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: kbCol.implicitHeight + 24
                            color: localTheme.surface
                            border.color: localTheme.border
                            border.width: 1
                            radius: localTheme.radius

                            ColumnLayout {
                                id: kbCol
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 10

                                Text {
                                    text: "[ 05 // KEYBOARD SHORTCUTS & VIM NAVIGATION ]"
                                    color: localTheme.accent
                                    font.bold: true
                                    font.pixelSize: 11
                                    font.family: "monospace"
                                }

                                GridLayout {
                                    columns: 2
                                    rowSpacing: 6
                                    columnSpacing: 16
                                    Layout.fillWidth: true

                                    Repeater {
                                        model: [
                                            { key: "[ Space ]", action: "Toggle Play / Pause" },
                                            { key: "[ z ] / [ x ]", action: "Master Volume Down / Up" },
                                            { key: "[ c ] / [ v ]", action: "Seek Timeline -5s / +5s" },
                                            { key: "[ p ]", action: "Toggle Bit-Perfect Pure 0dB Mode" },
                                            { key: "[ m ]", action: "Mute / Restore Volume" },
                                            { key: "[ Mouse Wheel ]", action: "Smooth Volume Fade on Slider" },
                                            { key: "[ Click Timeline ]", action: "Instant Absolute Track Seek" },
                                            { key: "[ 1 - 6 ]", action: "Switch View (Queue, Albums, EQ...)" }
                                        ]

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8

                                            Rectangle {
                                                Layout.preferredWidth: 120
                                                Layout.preferredHeight: 22
                                                color: localTheme.darkBackground
                                                border.color: localTheme.border
                                                border.width: 1
                                                radius: localTheme.radius

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: modelData.key
                                                    color: localTheme.accent
                                                    font.bold: true
                                                    font.pixelSize: 10
                                                    font.family: "monospace"
                                                }
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.action
                                                color: localTheme.foreground
                                                font.pixelSize: 10
                                                font.family: "monospace"
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // 4. BOTTOM STATUS BAR: [NORMAL] | [Signal Integrity] | [Stats]
        // =====================================================================
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 24
            spacing: 12

            // VIM MODE PILL BADGE: [NORMAL]
            Rectangle {
                Layout.preferredHeight: 20
                Layout.preferredWidth: modeText.implicitWidth + 14
                radius: 3
                color: localTheme.darkBackground
                border.color: localTheme.accent
                border.width: 1

                Text {
                    id: modeText
                    anchors.centerIn: parent
                    text: localBackend.isPlaying ? "PLAYING" : "NORMAL"
                    color: localTheme.accent
                    font.bold: true
                    font.pixelSize: 10
                    font.family: "monospace"
                }
            }

            // SIGNAL PATH STATUS BADGE
            Text {
                text: localBackend.isBitPerfect ? "[PURE 0dB: BIT-PERFECT DIRECT]" : "[AUDITED DSP ACTIVE]"
                color: localBackend.isBitPerfect ? localTheme.green : localTheme.yellow
                font.bold: true
                font.pixelSize: 10
                font.family: "monospace"
            }

            Item { Layout.fillWidth: true }

            // STATS: XX songs / total time
            Text {
                text: localBackend.tracks.length + " songs / " + (localBackend.isBitPerfect ? "Bit-Perfect" : "DSP") + " mode active"
                color: localTheme.muted
                font.pixelSize: 10
                font.family: "monospace"
            }
        }
    }

    function formatDuration(ms) {
        if (!ms || ms <= 0) return "0:00";
        var totalSec = Math.floor(ms / 1000);
        var min = Math.floor(totalSec / 60);
        var sec = totalSec % 60;
        return min + ":" + (sec < 10 ? "0" + sec : sec);
    }
}
