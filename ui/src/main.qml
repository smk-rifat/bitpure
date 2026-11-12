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
    title: "Audiophile Player — " + localTheme.currentTheme.toUpperCase()

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
                            text: "── Signal Path & Lyrics ──"
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
                                text: "HARDWARE DAC:"
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

                            // 10-Band EQ status
                            Text {
                                text: "DSP / EQUALIZER:"
                                color: localTheme.muted
                                font.bold: true
                                font.pixelSize: 9
                                font.family: "monospace"
                            }
                            RowLayout {
                                spacing: 4
                                Repeater {
                                    model: ["Flat", "Balanced", "Bass+", "Warm"]
                                    Rectangle {
                                        Layout.preferredWidth: 44
                                        Layout.preferredHeight: 20
                                        radius: localTheme.radius
                                        color: localBackend.activeEqPreset === index ? localTheme.accent : localTheme.darkBackground
                                        border.color: localTheme.border
                                        border.width: 1

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData
                                            color: localBackend.activeEqPreset === index ? localTheme.darkBackground : localTheme.foreground
                                            font.pixelSize: 9
                                            font.family: "monospace"
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (localBackend.isBitPerfect) {
                                                    localBackend.isBitPerfect = false;
                                                }
                                                localBackend.activeEqPreset = index;
                                            }
                                        }
                                    }
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

                // C. SETTINGS VIEW
                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 20
                    visible: currentTab === "settings"
                    clip: true

                    ColumnLayout {
                        width: parent.width
                        spacing: 16

                        Text {
                            text: "SETTINGS & ARCHITECTURE CONFIGURATION"
                            color: localTheme.accent
                            font.bold: true
                            font.pixelSize: 13
                            font.family: "monospace"
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: localTheme.border }

                        // 1. Music Folder
                        ColumnLayout {
                            spacing: 6
                            Text {
                                text: "1. LOCAL MUSIC LIBRARY PATH"
                                color: localTheme.foreground
                                font.bold: true
                                font.pixelSize: 11
                                font.family: "monospace"
                            }
                            RowLayout {
                                spacing: 8
                                Rectangle {
                                    Layout.preferredWidth: 380
                                    Layout.preferredHeight: 30
                                    color: localTheme.darkBackground
                                    border.color: localTheme.border
                                    border.width: 1
                                    radius: localTheme.radius

                                    TextInput {
                                        id: folderInput
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        text: localBackend.musicFolder
                                        color: localTheme.foreground
                                        font.pixelSize: 11
                                        font.family: "monospace"
                                    }
                                }
                                Rectangle {
                                    Layout.preferredWidth: 90
                                    Layout.preferredHeight: 30
                                    color: localTheme.accent
                                    radius: localTheme.radius

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Scan Now"
                                        color: localTheme.darkBackground
                                        font.bold: true
                                        font.pixelSize: 10
                                        font.family: "monospace"
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: localBackend.setMusicFolder(folderInput.text)
                                    }
                                }
                            }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: localTheme.border }

                        // 2. Output Device
                        ColumnLayout {
                            spacing: 6
                            Text {
                                text: "2. HARDWARE AUDIO ENDPOINT"
                                color: localTheme.foreground
                                font.bold: true
                                font.pixelSize: 11
                                font.family: "monospace"
                            }
                            Repeater {
                                model: localBackend.devices
                                Rectangle {
                                    Layout.preferredWidth: 480
                                    Layout.preferredHeight: 32
                                    color: localBackend.activeDeviceId === modelData.id ? localTheme.selection : localTheme.darkBackground
                                    border.color: localBackend.activeDeviceId === modelData.id ? localTheme.accent : localTheme.border
                                    border.width: 1
                                    radius: localTheme.radius

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        Text {
                                            text: (localBackend.activeDeviceId === modelData.id ? "● " : "○ ") + modelData.name
                                            color: localBackend.activeDeviceId === modelData.id ? localTheme.accent : localTheme.foreground
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

                        Rectangle { Layout.fillWidth: true; height: 1; color: localTheme.border }

                        // 3. Theme Selector
                        ColumnLayout {
                            spacing: 8
                            Text {
                                text: "3. DESKTOP THEMES & PALETTES"
                                color: localTheme.foreground
                                font.bold: true
                                font.pixelSize: 11
                                font.family: "monospace"
                            }
                            Text {
                                text: "Accurate Neovim & Omarchy colors: Everforest, Gruvbox, Nord, Tokyo Night, etc."
                                color: localTheme.muted
                                font.pixelSize: 10
                                font.family: "monospace"
                            }
                            Flow {
                                Layout.preferredWidth: 540
                                spacing: 8
                                Repeater {
                                    model: localTheme.availableThemes
                                    Rectangle {
                                        width: 115
                                        height: 28
                                        radius: localTheme.radius
                                        color: localTheme.currentTheme === modelData ? localTheme.accent : localTheme.darkBackground
                                        border.color: localTheme.border
                                        border.width: 1

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData
                                            color: localTheme.currentTheme === modelData ? localTheme.darkBackground : localTheme.foreground
                                            font.bold: true
                                            font.pixelSize: 10
                                            font.family: "monospace"
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: localTheme.currentTheme = modelData
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
