import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Audioplayer 1.0

ApplicationWindow {
    id: root
    visible: true
    width: 1060
    height: 700
    minimumWidth: 860
    minimumHeight: 580
    title: "BitPure — " + localTheme.family + " (" + localTheme.variant + ")"

    // Statically-typed bindings to root C++ context properties
    readonly property Theme localTheme: theme
    readonly property Backend localBackend: backend

    // Helper functions for dynamic typography
    function appFontFamily() {
        return (settingsManager && settingsManager.fontFamily !== "System Default" && settingsManager.fontFamily.length > 0)
            ? settingsManager.fontFamily : "monospace";
    }

    function appFontSize(baseSize) {
        var scale = (settingsManager && settingsManager.fontSizeScale > 0) ? settingsManager.fontSizeScale : 1.0;
        return Math.max(8, Math.round(baseSize * scale));
    }

    // Active navigation and state
    property string currentTab: "home" // home, queue, albums, artists, playlists, history, liked, all, settings
    property string currentSettingsTab: "appearance" // appearance, audio, playback, library, lyrics, advanced
    property string activeMood: ""
    property var selectedAlbum: null
    property var selectedAlbumTracks: []

    // Global keyboard navigation
    Item {
        id: globalKeyHandler
        focus: true
        Component.onCompleted: forceActiveFocus()
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Space) {
                if (localBackend.isPlaying) localBackend.pause();
                else if (localBackend.tracks.length > 0) {
                    var trk = (localBackend.playQueue.length > 0) ? localBackend.playQueue[0] : localBackend.tracks[0];
                    localBackend.playTrack(trk.file_path, trk.title, trk.track_artist);
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_N) {
                if (event.modifiers & Qt.ShiftModifier) {
                    localBackend.previousTrack();
                } else {
                    localBackend.nextTrack();
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_S) {
                localBackend.cycleShuffleMode();
                event.accepted = true;
            } else if (event.key === Qt.Key_R) {
                localBackend.cycleRepeatMode();
                event.accepted = true;
            } else if (event.key === Qt.Key_P) {
                localBackend.isBitPerfect = !localBackend.isBitPerfect;
                event.accepted = true;
            } else if (event.key === Qt.Key_Z) {
                localBackend.volume = Math.max(0.0, localBackend.volume - 0.05);
                event.accepted = true;
            } else if (event.key === Qt.Key_X) {
                localBackend.volume = Math.min(1.0, localBackend.volume + 0.05);
                event.accepted = true;
            } else if (event.key === Qt.Key_C) {
                localBackend.seekTo(Math.max(0, localBackend.positionMs - 5000));
                event.accepted = true;
            } else if (event.key === Qt.Key_V) {
                localBackend.seekTo(Math.min(localBackend.durationMs, localBackend.positionMs + 5000));
                event.accepted = true;
            } else if (event.key === Qt.Key_T) {
                localTheme.cycleFamily();
                event.accepted = true;
            } else if (event.key === Qt.Key_Y) {
                localTheme.cycleVariant();
                event.accepted = true;
            } else if (event.key === Qt.Key_M) {
                var moods = ["Sad", "Fun", "Rock", "Traveling", "Chill", "Energetic"];
                var mIdx = (moods.indexOf(activeMood) + 1) % moods.length;
                activeMood = moods[mIdx];
                localBackend.playMood(activeMood);
                event.accepted = true;
            } else if (event.key === Qt.Key_F1) {
                if (currentTab === "settings") currentSettingsTab = "appearance";
                event.accepted = true;
            } else if (event.key === Qt.Key_F2) {
                if (currentTab === "settings") currentSettingsTab = "audio";
                event.accepted = true;
            } else if (event.key === Qt.Key_F3) {
                if (currentTab === "settings") currentSettingsTab = "playback";
                event.accepted = true;
            } else if (event.key === Qt.Key_F4) {
                if (currentTab === "settings") currentSettingsTab = "library";
                event.accepted = true;
            } else if (event.key === Qt.Key_F5) {
                if (currentTab === "settings") currentSettingsTab = "lyrics";
                event.accepted = true;
            } else if (event.key === Qt.Key_F6) {
                if (currentTab === "settings") currentSettingsTab = "advanced";
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace) {
                if (selectedAlbum !== null) {
                    selectedAlbum = null;
                    event.accepted = true;
                }
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (currentTab === "albums" && selectedAlbum === null && localBackend.albums.length > 0) {
                    selectedAlbum = localBackend.albums[0];
                    selectedAlbumTracks = localBackend.getAlbumTracks(selectedAlbum.id);
                    event.accepted = true;
                }
            } else if ((event.key >= Qt.Key_1 && event.key <= Qt.Key_9) || (event.text >= "1" && event.text <= "9")) {
                var tabs = ["home", "queue", "albums", "artists", "playlists", "history", "liked", "all", "settings"];
                var idx = (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) ? (event.key - Qt.Key_1) : (parseInt(event.text) - 1);
                if (idx >= 0 && idx < tabs.length) {
                    currentTab = tabs[idx];
                    if (currentTab !== "albums") selectedAlbum = null;
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Menu || event.key === Qt.Key_F10) {
                if (localBackend.tracks.length > 0) {
                    var trkIdx = (trackTable && trackTable.currentIndex >= 0) ? trackTable.currentIndex : 0;
                    contextMenu.openMenu(localBackend.tracks[trkIdx], 350, 200, root.contentItem);
                }
                event.accepted = true;
            }
        }
    }

    color: localTheme.background

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        // =====================================================================
        // 1. TOP HEADER BAR: Transport Controls, Title/Artist, Volume & Mode
        // =====================================================================
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            color: localTheme.surface
            border.color: localTheme.border
            border.width: 1
            radius: localTheme.radius

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 16

                // LEFT: Transport controls + Status
                ColumnLayout {
                    Layout.preferredWidth: 320
                    spacing: 3

                    // Prev | Play/Pause | Next | Shuffle | Repeat
                    RowLayout {
                        spacing: 5

                        // Prev
                        Rectangle {
                            width: 24
                            height: 24
                            radius: 2
                            color: prevBtnMouse.containsMouse ? localTheme.surfaceElevated : "transparent"
                            border.color: localTheme.border
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "⏮"
                                color: localTheme.text
                                font.pixelSize: appFontSize(9)
                            }

                            MouseArea {
                                id: prevBtnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: localBackend.previousTrack()
                            }
                        }

                        // Play/Pause
                        Rectangle {
                            width: 28
                            height: 24
                            radius: 2
                            color: localTheme.background
                            border.color: localTheme.accent
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: localBackend.isPlaying ? "⏸" : "▶"
                                color: localTheme.accent
                                font.bold: true
                                font.pixelSize: appFontSize(11)
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (localBackend.isPlaying) localBackend.pause();
                                    else if (localBackend.tracks.length > 0) {
                                        var trk = (localBackend.playQueue.length > 0) ? localBackend.playQueue[0] : localBackend.tracks[0];
                                        localBackend.playTrack(trk.file_path, trk.title, trk.track_artist);
                                    }
                                }
                            }
                        }

                        // Next
                        Rectangle {
                            width: 24
                            height: 24
                            radius: 2
                            color: nextBtnMouse.containsMouse ? localTheme.surfaceElevated : "transparent"
                            border.color: localTheme.border
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "⏭"
                                color: localTheme.text
                                font.pixelSize: appFontSize(9)
                            }

                            MouseArea {
                                id: nextBtnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: localBackend.nextTrack()
                            }
                        }

                        // Shuffle Pill
                        Rectangle {
                            height: 24
                            width: shufText.implicitWidth + 12
                            radius: 2
                            color: localBackend.shuffleMode === 2 ? localTheme.accent : (localBackend.shuffleMode === 1 ? localTheme.selection : "transparent")
                            border.color: localBackend.shuffleMode > 0 ? localTheme.accent : localTheme.border
                            border.width: 1

                            Text {
                                id: shufText
                                anchors.centerIn: parent
                                text: localBackend.shuffleMode === 2 ? "✨ Smart" : (localBackend.shuffleMode === 1 ? "🔀 Normal" : "→ Order")
                                color: localBackend.shuffleMode === 2 ? localTheme.background : (localBackend.shuffleMode === 1 ? localTheme.accent : localTheme.textMuted)
                                font.bold: localBackend.shuffleMode > 0
                                font.pixelSize: appFontSize(9)
                                font.family: appFontFamily()
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: localBackend.cycleShuffleMode()
                            }
                        }

                        // Repeat Pill
                        Rectangle {
                            height: 24
                            width: repText.implicitWidth + 12
                            radius: 2
                            color: localBackend.repeatMode > 0 ? localTheme.selection : "transparent"
                            border.color: localBackend.repeatMode > 0 ? localTheme.statusSuccess : localTheme.border
                            border.width: 1

                            Text {
                                id: repText
                                anchors.centerIn: parent
                                text: localBackend.repeatMode === 2 ? "🔂 One" : (localBackend.repeatMode === 1 ? "🔁 All" : "Off")
                                color: localBackend.repeatMode > 0 ? localTheme.statusSuccess : localTheme.textMuted
                                font.bold: localBackend.repeatMode > 0
                                font.pixelSize: appFontSize(9)
                                font.family: appFontFamily()
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: localBackend.cycleRepeatMode()
                            }
                        }
                    }

                    // Status & Time readout
                    RowLayout {
                        spacing: 6

                        Text {
                            text: localBackend.isPlaying ? "[Playing]" : "[Stopped]"
                            color: localBackend.isPlaying ? localTheme.statusSuccess : localTheme.statusWarning
                            font.bold: true
                            font.pixelSize: appFontSize(10)
                            font.family: appFontFamily()
                        }

                        Text {
                            text: (localBackend.positionStr.length > 0 ? localBackend.positionStr : "0:00") + " / " + (localBackend.durationStr.length > 0 ? localBackend.durationStr : "0:00")
                            color: localTheme.text
                            font.pixelSize: appFontSize(10)
                            font.family: appFontFamily()
                        }
                    }
                }

                // CENTER: Now Playing Title & Artist
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 2

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: localBackend.nowPlayingTitle.length > 0 ? localBackend.nowPlayingTitle : "BitPure Lossless"
                        color: localTheme.text
                        font.bold: true
                        font.pixelSize: appFontSize(13)
                        font.family: appFontFamily()
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: localBackend.nowPlayingArtist.length > 0 ? localBackend.nowPlayingArtist : "Select a track to start listening"
                        color: localTheme.accent
                        font.pixelSize: appFontSize(10)
                        font.family: appFontFamily()
                        elide: Text.ElideRight
                    }
                }

                // RIGHT: Interactive Volume Bar & Mode
                ColumnLayout {
                    Layout.preferredWidth: 210
                    Layout.alignment: Qt.AlignRight
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        // Speaker Icon
                        Text {
                            text: localBackend.isBitPerfect ? "🔊" : (localBackend.volume === 0 ? "🔇" : "🔉")
                            color: localBackend.isBitPerfect ? localTheme.statusSuccess : localTheme.accent
                            font.pixelSize: appFontSize(12)

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (localBackend.isBitPerfect) {
                                        localBackend.isBitPerfect = false;
                                    } else {
                                        localBackend.volume = (localBackend.volume === 0 ? 0.50 : 0.0);
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

                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width
                                height: 2
                                color: localTheme.border

                                Rectangle {
                                    height: parent.height
                                    width: parent.width * localBackend.volume
                                    color: localBackend.isBitPerfect ? localTheme.statusSuccess : localTheme.accent
                                }
                            }

                            Rectangle {
                                y: parent.height / 2 - 4
                                x: Math.max(0, Math.min(parent.width - 8, (parent.width * localBackend.volume) - 4))
                                width: 8
                                height: 8
                                radius: 4
                                color: localBackend.isBitPerfect ? localTheme.statusSuccess : localTheme.accent
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
                            color: localBackend.isBitPerfect ? localTheme.statusSuccess : localTheme.accent
                            font.bold: true
                            font.pixelSize: appFontSize(11)
                            font.family: appFontFamily()
                        }
                    }

                    // Pure Mode / DSP status
                    RowLayout {
                        Layout.alignment: Qt.AlignRight
                        spacing: 6

                        Text {
                            text: localBackend.isBitPerfect ? "[PURE 0dB LINE-OUT]" : "[AUDITED DSP]"
                            color: localBackend.isBitPerfect ? localTheme.statusSuccess : localTheme.statusWarning
                            font.pixelSize: appFontSize(10)
                            font.family: appFontFamily()

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: localBackend.isBitPerfect = !localBackend.isBitPerfect
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // 1.5 TRACK PROGRESS & SEEK BAR
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
                    color: localBackend.isPlaying ? localTheme.statusSuccess : localTheme.text
                    font.bold: true
                    font.pixelSize: appFontSize(11)
                    font.family: appFontFamily()
                }

                Item {
                    id: seekAreaItem
                    Layout.fillWidth: true
                    Layout.preferredHeight: parent.height

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width
                        height: 4
                        radius: 2
                        color: localTheme.background

                        Rectangle {
                            height: parent.height
                            width: Math.max(0, Math.min(parent.width, parent.width * localBackend.progress))
                            radius: 2
                            color: localBackend.isBitPerfect ? localTheme.statusSuccess : localTheme.accent
                        }
                    }

                    Rectangle {
                        y: parent.height / 2 - 5
                        x: Math.max(0, Math.min(parent.width - 10, (parent.width * localBackend.progress) - 5))
                        width: 10
                        height: 10
                        radius: 5
                        color: localBackend.isBitPerfect ? localTheme.statusSuccess : localTheme.accent
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
                    color: localTheme.textMuted
                    font.bold: true
                    font.pixelSize: appFontSize(11)
                    font.family: appFontFamily()
                }
            }
        }

        // =====================================================================
        // 2. NAVIGATION BAR & MOOD SHELF
        // =====================================================================
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            // Tabs: Home | Queue | Albums | Artists | Playlists | History | Liked | All Songs | Settings
            Repeater {
                model: [
                    { id: "home", label: "Home" },
                    { id: "queue", label: "Queue" },
                    { id: "albums", label: "Albums" },
                    { id: "artists", label: "Artists" },
                    { id: "playlists", label: "Playlists" },
                    { id: "history", label: "History" },
                    { id: "liked", label: "♥ Liked" },
                    { id: "all", label: "All Songs" },
                    { id: "settings", label: "Settings" }
                ]

                Rectangle {
                    Layout.preferredHeight: 26
                    Layout.preferredWidth: tabText.implicitWidth + 20
                    radius: localTheme.radius
                    color: currentTab === modelData.id ? localTheme.accent : (tabMouse.containsMouse ? localTheme.surfaceElevated : "transparent")
                    border.color: currentTab === modelData.id ? localTheme.accent : localTheme.border
                    border.width: 1

                    Text {
                        id: tabText
                        anchors.centerIn: parent
                        text: modelData.label
                        color: currentTab === modelData.id ? localTheme.background : localTheme.text
                        font.bold: currentTab === modelData.id
                        font.pixelSize: appFontSize(11)
                        font.family: appFontFamily()
                    }

                    MouseArea {
                        id: tabMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            currentTab = modelData.id;
                            if (modelData.id !== "albums") selectedAlbum = null;
                            if (modelData.id === "all") localBackend.setSortCriteria(0);
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // MOOD SHELF (Replaces old theme button on main page!)
            RowLayout {
                spacing: 4
                Layout.alignment: Qt.AlignVCenter

                Text {
                    text: "MOOD:"
                    color: localTheme.textMuted
                    font.bold: true
                    font.pixelSize: appFontSize(10)
                    font.family: appFontFamily()
                }

                Repeater {
                    model: ["Sad", "Fun", "Rock", "Traveling", "Chill", "Energetic"]

                    Rectangle {
                        Layout.preferredHeight: 24
                        Layout.preferredWidth: moodLabel.implicitWidth + 14
                        radius: localTheme.radius
                        color: activeMood === modelData ? localTheme.accent : (moodMouse.containsMouse ? localTheme.surfaceElevated : localTheme.surface)
                        border.color: activeMood === modelData ? localTheme.accent : localTheme.border
                        border.width: 1

                        Text {
                            id: moodLabel
                            anchors.centerIn: parent
                            text: modelData
                            color: activeMood === modelData ? localTheme.background : (moodMouse.containsMouse ? localTheme.accent : localTheme.text)
                            font.bold: activeMood === modelData
                            font.pixelSize: appFontSize(10)
                            font.family: appFontFamily()
                        }

                        MouseArea {
                            id: moodMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                activeMood = modelData;
                                localBackend.playMood(modelData);
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // 3. MAIN DUAL-PANE BODY: Left (Cover & Lyrics) + Right (Content)
        // =====================================================================
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            // -----------------------------------------------------------------
            // LEFT PANE: Album Art Box + Synced Lyrics Box
            // -----------------------------------------------------------------
            Rectangle {
                Layout.preferredWidth: 320
                Layout.fillHeight: true
                color: localTheme.surface
                border.color: localTheme.border
                border.width: 1
                radius: localTheme.radius

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    // ALBUM ARTWORK CONTAINER
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 220
                        color: localTheme.background
                        border.color: localTheme.border
                        border.width: 1
                        radius: localTheme.radius

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "💿"
                                color: localTheme.text
                                font.pixelSize: 48
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: localBackend.nowPlayingTitle.length > 0 ? localBackend.nowPlayingTitle : "BitPure Lossless"
                                color: localTheme.text
                                font.bold: true
                                font.pixelSize: appFontSize(11)
                                font.family: appFontFamily()
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: localBackend.formatBadge
                                color: localTheme.accent
                                font.pixelSize: appFontSize(10)
                                font.family: appFontFamily()
                            }
                        }
                    }

                    // ── Synced Lyrics Header with Translation Toggle ──
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: "── Synced Lyrics ──"
                            color: localTheme.textMuted
                            font.bold: true
                            font.pixelSize: appFontSize(10)
                            font.family: appFontFamily()
                        }

                        Item { Layout.fillWidth: true }

                        // Translation Toggle Button
                        Rectangle {
                            Layout.preferredHeight: 20
                            Layout.preferredWidth: trBtnText.implicitWidth + 10
                            radius: 2
                            color: localBackend.lyricsTranslationEnabled ? localTheme.accent : localTheme.background
                            border.color: localTheme.border
                            border.width: 1

                            Text {
                                id: trBtnText
                                anchors.centerIn: parent
                                text: localBackend.lyricsTranslationEnabled ? "EN: ON" : "EN: OFF"
                                color: localBackend.lyricsTranslationEnabled ? localTheme.background : localTheme.textMuted
                                font.bold: true
                                font.pixelSize: appFontSize(9)
                                font.family: appFontFamily()
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: localBackend.lyricsTranslationEnabled = !localBackend.lyricsTranslationEnabled
                            }
                        }
                    }

                    // MINIMAL ONE-LINE SYNCED LYRIC DISPLAY
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 64
                        color: localTheme.background
                        border.color: localBackend.currentLyricLine !== "" ? localTheme.accent : localTheme.border
                        border.width: 1
                        radius: 2

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 3

                            // Primary Synced Lyric Line
                            Text {
                                Layout.fillWidth: true
                                text: localBackend.currentLyricLine !== "" ? ("♪  " + localBackend.currentLyricLine) : (localBackend.isPlaying ? "(waiting for lyrics...)" : "Ready")
                                color: localBackend.currentLyricLine !== "" ? localTheme.lyricsCurrent : localTheme.textMuted
                                font.bold: true
                                font.pixelSize: appFontSize(11)
                                font.family: appFontFamily()
                                elide: Text.ElideRight

                                Behavior on opacity {
                                    NumberAnimation { duration: 150 }
                                }
                            }

                            // Translated Line (when translation is enabled)
                            Text {
                                visible: localBackend.lyricsTranslationEnabled && localBackend.translatedLyricLine !== ""
                                Layout.fillWidth: true
                                text: "[EN] " + localBackend.translatedLyricLine
                                color: localTheme.accent
                                font.pixelSize: appFontSize(10)
                                font.family: appFontFamily()
                                elide: Text.ElideRight

                                Behavior on opacity {
                                    NumberAnimation { duration: 150 }
                                }
                            }
                        }
                    }

                    // Synced Lyrics Dynamic Flow (Real-time auto-scrolling with timestamp seeking)
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        // CASE 1: Synced Lyrics lines available
                        ListView {
                            id: syncedLyricsList
                            anchors.fill: parent
                            clip: true
                            spacing: 4
                            visible: localBackend.syncedLyricsLines.length > 0
                            model: localBackend.syncedLyricsLines

                            Connections {
                                target: localBackend
                                function onCurrentLyricIndexChanged() {
                                    if (localBackend.currentLyricIndex >= 0 && localBackend.currentLyricIndex < syncedLyricsList.count) {
                                        syncedLyricsList.positionViewAtIndex(localBackend.currentLyricIndex, ListView.Center);
                                    }
                                }
                            }

                            delegate: Rectangle {
                                width: syncedLyricsList.width
                                height: Math.max(22, lineCol.implicitHeight + 6)
                                radius: 2
                                color: index === localBackend.currentLyricIndex
                                       ? localTheme.selection
                                       : (lyrMouse.containsMouse ? localTheme.surfaceElevated : "transparent")

                                RowLayout {
                                    id: lineCol
                                    anchors.fill: parent
                                    anchors.leftMargin: 6
                                    anchors.rightMargin: 6
                                    spacing: 6

                                    Text {
                                        Layout.preferredWidth: 28
                                        text: index === localBackend.currentLyricIndex ? "▶" : modelData.timeStr
                                        color: index === localBackend.currentLyricIndex ? localTheme.accent : localTheme.textMuted
                                        font.bold: index === localBackend.currentLyricIndex
                                        font.pixelSize: appFontSize(8)
                                        font.family: appFontFamily()
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.text
                                        color: index === localBackend.currentLyricIndex
                                               ? localTheme.lyricsCurrent
                                               : (index < localBackend.currentLyricIndex ? localTheme.lyricsPrevious : localTheme.lyricsInactive)
                                        font.bold: index === localBackend.currentLyricIndex
                                        font.pixelSize: index === localBackend.currentLyricIndex ? appFontSize(11) : appFontSize(10)
                                        font.family: appFontFamily()
                                        wrapMode: Text.Wrap
                                    }
                                }

                                MouseArea {
                                    id: lyrMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: localBackend.seekTo(modelData.timeMs)
                                }
                            }
                        }

                        // CASE 2: Plain text or empty state
                        ScrollView {
                            anchors.fill: parent
                            visible: localBackend.syncedLyricsLines.length === 0
                            clip: true
                            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                            Text {
                                width: parent.width
                                text: localBackend.lyrics !== "" ? localBackend.lyrics : "(no lyrics loaded)"
                                color: localBackend.lyrics !== "" ? localTheme.textMuted : localTheme.border
                                font.pixelSize: appFontSize(10)
                                font.family: appFontFamily()
                                wrapMode: Text.Wrap
                                lineHeight: 1.4
                            }
                        }
                    }

                    // Format Badge Footer
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 24
                        color: localTheme.background
                        border.color: localTheme.border
                        border.width: 1
                        radius: 2

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 6

                            Text {
                                text: localBackend.formatBadge
                                color: localBackend.isBitPerfect ? localTheme.statusSuccess : localTheme.statusWarning
                                font.pixelSize: appFontSize(9)
                                font.family: appFontFamily()
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: localBackend.isBitPerfect ? "PURE" : "DSP"
                                color: localBackend.isBitPerfect ? localTheme.statusSuccess : localTheme.statusWarning
                                font.pixelSize: appFontSize(9)
                                font.family: appFontFamily()
                            }
                        }
                    }
                }
            }

            // -----------------------------------------------------------------
            // RIGHT PANE: Smooth Transition Container (Track Table / Albums / Settings)
            // -----------------------------------------------------------------
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: localTheme.surface
                border.color: localTheme.border
                border.width: 1
                radius: localTheme.radius

                Item {
                    id: viewTransitionContainer
                    anchors.fill: parent

                    property string activeViewKey: currentTab + (selectedAlbum ? "_detail" : "")

                    onActiveViewKeyChanged: {
                        if (!settingsManager.reducedMotion) {
                            tabTransitionAnim.restart();
                        }
                    }

                    ParallelAnimation {
                        id: tabTransitionAnim
                        NumberAnimation {
                            target: viewTransitionContainer
                            property: "opacity"
                            from: 0.25
                            to: 1.0
                            duration: 150
                            easing.type: Easing.OutCubic
                        }
                    }

                    // =========================================================
                    // VIEW 0: HOME / DISCOVERY VIEW
                    // =========================================================
                    ScrollView {
                        id: homeScrollView
                        anchors.fill: parent
                        anchors.margins: 14
                        visible: currentTab === "home"
                        clip: true
                        ScrollBar.vertical.policy: ScrollBar.AsNeeded

                        ColumnLayout {
                            width: homeScrollView.availableWidth
                            spacing: 14

                            // 1. Lossless Audiophile Header Banner
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 68
                                color: localTheme.surfaceElevated
                                border.color: localTheme.border
                                border.width: 1
                                radius: 4

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 12

                                    Rectangle {
                                        width: 40
                                        height: 40
                                        radius: 20
                                        color: localTheme.surface
                                        border.color: localTheme.accent
                                        border.width: 1

                                        Text {
                                            anchors.centerIn: parent
                                            text: "⚡"
                                            font.pixelSize: appFontSize(16)
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        Text {
                                            text: "BitPure Lossless Audio Engine"
                                            color: localTheme.text
                                            font.bold: true
                                            font.pixelSize: appFontSize(13)
                                            font.family: appFontFamily()
                                        }

                                        Text {
                                            text: "Pure bit-perfect playback • Direct ALSA hardware integration • Studio Master Quality"
                                            color: localTheme.textMuted
                                            font.pixelSize: appFontSize(9)
                                            font.family: appFontFamily()
                                        }
                                    }

                                    Rectangle {
                                        Layout.preferredHeight: 26
                                        Layout.preferredWidth: 150
                                        color: localTheme.surface
                                        border.color: localTheme.accent
                                        border.width: 1
                                        radius: 2

                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: 6
                                            Rectangle { width: 6; height: 6; radius: 3; color: localTheme.statusSuccess }
                                            Text {
                                                text: localBackend.isBitPerfect ? "DIRECT BIT-PERFECT" : "DSP ACTIVE"
                                                color: localTheme.accent
                                                font.bold: true
                                                font.pixelSize: appFontSize(9)
                                                font.family: appFontFamily()
                                            }
                                        }
                                    }
                                }
                            }

                            // 2. MOOD PLAYBACK SECTION
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: homeMoodCol.implicitHeight + 24
                                color: localTheme.background
                                border.color: localTheme.border
                                border.width: 1
                                radius: 4

                                ColumnLayout {
                                    id: homeMoodCol
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 10

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text {
                                            text: "MOOD-BASED MUSIC PLAYBACK"
                                            color: localTheme.accent
                                            font.bold: true
                                            font.pixelSize: appFontSize(11)
                                            font.family: appFontFamily()
                                        }
                                        Item { Layout.fillWidth: true }
                                        Text {
                                            text: activeMood ? ("Current Session: " + activeMood) : "Select a mood to start curated listening"
                                            color: activeMood ? localTheme.accent : localTheme.textMuted
                                            font.pixelSize: appFontSize(9)
                                            font.family: appFontFamily()
                                        }
                                    }

                                    Flow {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Repeater {
                                            model: [
                                                { name: "Sad", emoji: "🌧", desc: "Soulful, melancholic ballads" },
                                                { name: "Fun", emoji: "🎉", desc: "Upbeat energetic rhythms" },
                                                { name: "Rock", emoji: "🎸", desc: "Driving guitars & punchy beats" },
                                                { name: "Traveling", emoji: "🚗", desc: "Atmospheric open-road melodies" },
                                                { name: "Chill", emoji: "☕", desc: "Relaxed acoustic vibes" },
                                                { name: "Energetic", emoji: "⚡", desc: "High-octane dynamic anthems" }
                                            ]

                                            Rectangle {
                                                height: 34
                                                width: homeMoodBtnRow.implicitWidth + 20
                                                radius: 3
                                                color: activeMood === modelData.name ? localTheme.accent : (homeMoodCardMouse.containsMouse ? localTheme.surfaceElevated : localTheme.surface)
                                                border.color: activeMood === modelData.name ? localTheme.accent : localTheme.border
                                                border.width: 1

                                                RowLayout {
                                                    id: homeMoodBtnRow
                                                    anchors.centerIn: parent
                                                    spacing: 6
                                                    Text {
                                                        text: modelData.emoji
                                                        font.pixelSize: appFontSize(12)
                                                    }
                                                    Text {
                                                        text: modelData.name
                                                        color: activeMood === modelData.name ? localTheme.background : localTheme.text
                                                        font.bold: true
                                                        font.pixelSize: appFontSize(10)
                                                        font.family: appFontFamily()
                                                    }
                                                }

                                                MouseArea {
                                                    id: homeMoodCardMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        activeMood = modelData.name;
                                                        localBackend.playMood(modelData.name);
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // 3. FEATURED ALBUMS ROW
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: "FEATURED ALBUMS"
                                        color: localTheme.text
                                        font.bold: true
                                        font.pixelSize: appFontSize(11)
                                        font.family: appFontFamily()
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: "View All (" + localBackend.albums.length + ") →"
                                        color: localTheme.accent
                                        font.pixelSize: appFontSize(10)
                                        font.family: appFontFamily()
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: currentTab = "albums"
                                        }
                                    }
                                }

                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Repeater {
                                        model: Math.min(8, localBackend.albums.length)

                                        Rectangle {
                                            width: 105
                                            height: 140
                                            color: homeAlbMouse.containsMouse ? localTheme.surfaceElevated : localTheme.surface
                                            border.color: homeAlbMouse.containsMouse ? localTheme.accent : localTheme.border
                                            border.width: 1
                                            radius: 3

                                            property var alb: localBackend.albums[index]

                                            ColumnLayout {
                                                anchors.fill: parent
                                                anchors.margins: 6
                                                spacing: 4

                                                Rectangle {
                                                    Layout.preferredWidth: 93
                                                    Layout.preferredHeight: 93
                                                    color: localTheme.background
                                                    radius: 2
                                                    clip: true

                                                    Image {
                                                        anchors.fill: parent
                                                        source: parent.parent.parent.alb && parent.parent.parent.alb.cover_art_path ? ("file://" + parent.parent.parent.alb.cover_art_path) : ""
                                                        fillMode: Image.PreserveAspectCrop
                                                        asynchronous: true
                                                        visible: status === Image.Ready
                                                    }

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "💿"
                                                        font.pixelSize: 26
                                                        visible: !parent.parent.parent.alb || !parent.parent.parent.alb.cover_art_path
                                                    }
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: parent.parent.alb ? parent.parent.alb.title : ""
                                                    color: localTheme.text
                                                    font.bold: true
                                                    font.pixelSize: appFontSize(9)
                                                    font.family: appFontFamily()
                                                    elide: Text.ElideRight
                                                    maximumLineCount: 1
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: parent.parent.alb ? parent.parent.alb.album_artist : ""
                                                    color: localTheme.accent
                                                    font.pixelSize: appFontSize(8)
                                                    font.family: appFontFamily()
                                                    elide: Text.ElideRight
                                                    maximumLineCount: 1
                                                }
                                            }

                                            MouseArea {
                                                id: homeAlbMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    selectedAlbum = parent.alb;
                                                    selectedAlbumTracks = localBackend.getAlbumTracks(parent.alb.id);
                                                    currentTab = "albums";
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // 4. QUICK STATS FOOTER
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 30
                                color: localTheme.surface
                                border.color: localTheme.border
                                border.width: 1
                                radius: 2

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 16

                                    Text {
                                        text: "Library: " + localBackend.tracks.length + " Lossless Tracks"
                                        color: localTheme.textMuted
                                        font.pixelSize: appFontSize(9)
                                        font.family: appFontFamily()
                                    }

                                    Text {
                                        text: "Albums: " + localBackend.albums.length
                                        color: localTheme.textMuted
                                        font.pixelSize: appFontSize(9)
                                        font.family: appFontFamily()
                                    }

                                    Item { Layout.fillWidth: true }

                                    Text {
                                        text: "Direct ALSA [hw:1,0] Line-Out Direct"
                                        color: localTheme.accent
                                        font.pixelSize: appFontSize(9)
                                        font.family: appFontFamily()
                                    }
                                }
                            }
                        }
                    }

                    // =========================================================
                    // VIEW A: TRACK TABLE (Queue, Liked, Playlists, Artists, All Songs, History)
                    // =========================================================
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 6
                        visible: currentTab === "queue" || currentTab === "liked" || currentTab === "playlists" || currentTab === "all" || currentTab === "artists" || currentTab === "history"

                        // SUB-HEADER BAR FOR PLAYLISTS / QUEUE / LIKED / HISTORY
                        RowLayout {
                            visible: currentTab === "playlists" || currentTab === "liked" || currentTab === "history" || (currentTab === "queue" && localBackend.playQueue.length > 0)
                            Layout.fillWidth: true
                            spacing: 8

                            // Playlists Sub-row
                            RowLayout {
                                visible: currentTab === "playlists"
                                Layout.fillWidth: true
                                spacing: 6

                                Text {
                                    text: "Playlists:"
                                    color: localTheme.textMuted
                                    font.pixelSize: appFontSize(10)
                                    font.family: appFontFamily()
                                }

                                Repeater {
                                    model: localBackend.playlistNames
                                    Rectangle {
                                        height: 22
                                        width: plPillText.implicitWidth + 14
                                        radius: 2
                                        color: localBackend.activePlaylistName === modelData ? localTheme.accent : localTheme.background
                                        border.color: localBackend.activePlaylistName === modelData ? localTheme.accent : localTheme.border
                                        border.width: 1

                                        Text {
                                            id: plPillText
                                            anchors.centerIn: parent
                                            text: modelData
                                            color: localBackend.activePlaylistName === modelData ? localTheme.background : localTheme.text
                                            font.bold: localBackend.activePlaylistName === modelData
                                            font.pixelSize: appFontSize(9)
                                            font.family: appFontFamily()
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: localBackend.setActivePlaylistName(modelData)
                                        }
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    height: 22
                                    width: 95
                                    radius: 2
                                    color: localTheme.background
                                    border.color: localTheme.accent
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: "+ New Playlist"
                                        color: localTheme.accent
                                        font.pixelSize: appFontSize(9)
                                        font.family: appFontFamily()
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: newPlaylistDialog.open()
                                    }
                                }
                            }

                            // Liked Sub-row
                            RowLayout {
                                visible: currentTab === "liked"
                                Layout.fillWidth: true
                                spacing: 6

                                Text {
                                    text: "♥ Liked Songs (" + localBackend.likedTracks.length + ") — Smart Shuffle prioritizes these tracks"
                                    color: localTheme.statusError
                                    font.bold: true
                                    font.pixelSize: appFontSize(10)
                                    font.family: appFontFamily()
                                }
                            }

                            // Queue Sub-row
                            RowLayout {
                                visible: currentTab === "queue" && localBackend.playQueue.length > 0
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: "Upcoming Queue (" + localBackend.playQueue.length + " tracks)"
                                    color: localTheme.statusSuccess
                                    font.bold: true
                                    font.pixelSize: appFontSize(10)
                                    font.family: appFontFamily()
                                }

                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    height: 20
                                    width: 75
                                    radius: 2
                                    color: localTheme.background
                                    border.color: localTheme.border
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Clear Queue"
                                        color: localTheme.textMuted
                                        font.pixelSize: appFontSize(9)
                                        font.family: appFontFamily()
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: localBackend.clearQueue()
                                    }
                                }
                            }

                            // History Sub-row
                            RowLayout {
                                visible: currentTab === "history"
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: "Listening History (" + localBackend.historyTracks.length + " tracks) — Most recently played first"
                                    color: localTheme.accent
                                    font.bold: true
                                    font.pixelSize: appFontSize(10)
                                    font.family: appFontFamily()
                                }
                            }
                        }

                        // TABLE HEADER BAR
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 24
                            color: localTheme.background
                            border.color: localTheme.border
                            border.width: 1
                            radius: localTheme.radius

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 8

                                Text {
                                    Layout.preferredWidth: 20
                                    text: "♥"
                                    color: localTheme.textMuted
                                    font.pixelSize: appFontSize(10)
                                }
                                Text {
                                    Layout.preferredWidth: 180
                                    text: "Artist"
                                    color: localTheme.textMuted
                                    font.bold: true
                                    font.pixelSize: appFontSize(11)
                                    font.family: appFontFamily()
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: "Title"
                                    color: localTheme.textMuted
                                    font.bold: true
                                    font.pixelSize: appFontSize(11)
                                    font.family: appFontFamily()
                                }
                                Text {
                                    Layout.preferredWidth: 180
                                    text: "Album"
                                    color: localTheme.textMuted
                                    font.bold: true
                                    font.pixelSize: appFontSize(11)
                                    font.family: appFontFamily()
                                }
                                Text {
                                    Layout.preferredWidth: 70
                                    horizontalAlignment: Text.AlignRight
                                    text: "Duration"
                                    color: localTheme.textMuted
                                    font.bold: true
                                    font.pixelSize: appFontSize(11)
                                    font.family: appFontFamily()
                                }
                            }
                        }

                        // TRACKS LIST
                        ListView {
                            id: trackTable
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            model: {
                                if (currentTab === "liked") return localBackend.likedTracks;
                                if (currentTab === "playlists") return localBackend.activePlaylistTracks;
                                if (currentTab === "history") return localBackend.historyTracks;
                                if (currentTab === "queue" && localBackend.playQueue.length > 0) return localBackend.playQueue;
                                return localBackend.tracks;
                            }

                            delegate: Rectangle {
                                width: trackTable.width
                                height: 28
                                radius: localTheme.radius
                                color: isCurrentTrack ? localTheme.selection : (rowMouse.containsMouse ? localTheme.surfaceElevated : "transparent")

                                property bool isCurrentTrack: localBackend.isPlaying && localBackend.nowPlayingTitle === modelData.title
                                property bool isLiked: localBackend.isTrackLiked(modelData.file_path)

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 8

                                    // Like Heart
                                    Text {
                                        Layout.preferredWidth: 20
                                        text: isLiked ? "♥" : "♡"
                                        color: isLiked ? localTheme.statusError : localTheme.textMuted
                                        font.pixelSize: appFontSize(11)

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: localBackend.toggleLikeTrack(modelData.file_path)
                                        }
                                    }

                                    // Artist
                                    Text {
                                        Layout.preferredWidth: 180
                                        text: modelData.track_artist
                                        color: isCurrentTrack ? localTheme.accent : localTheme.text
                                        font.bold: isCurrentTrack
                                        font.pixelSize: appFontSize(10)
                                        font.family: appFontFamily()
                                        elide: Text.ElideRight
                                    }

                                    // Title
                                    Text {
                                        Layout.fillWidth: true
                                        text: (isCurrentTrack ? "▶ " : "") + modelData.title
                                        color: isCurrentTrack ? localTheme.statusSuccess : localTheme.text
                                        font.bold: isCurrentTrack
                                        font.pixelSize: appFontSize(10)
                                        font.family: appFontFamily()
                                        elide: Text.ElideRight
                                    }

                                    // Album
                                    Text {
                                        Layout.preferredWidth: 180
                                        text: modelData.album_title ? modelData.album_title : "Lossless"
                                        color: localTheme.textMuted
                                        font.pixelSize: appFontSize(10)
                                        font.family: appFontFamily()
                                        elide: Text.ElideRight
                                    }

                                    // Duration
                                    Text {
                                        Layout.preferredWidth: 70
                                        horizontalAlignment: Text.AlignRight
                                        text: {
                                            var totalSec = Math.floor((modelData.duration_ms || 180000) / 1000);
                                            var min = Math.floor(totalSec / 60);
                                            var sec = totalSec % 60;
                                            return min + ":" + (sec < 10 ? "0" : "") + sec;
                                        }
                                        color: localTheme.textMuted
                                        font.pixelSize: appFontSize(10)
                                        font.family: appFontFamily()
                                    }
                                }

                                MouseArea {
                                    id: rowMouse
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: (mouse) => {
                                        if (mouse.button === Qt.RightButton) {
                                            contextMenu.openMenu(modelData, mouse.x, mouse.y, parent);
                                        } else {
                                            localBackend.playTrack(modelData.file_path, modelData.title, modelData.track_artist);
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // =========================================================
                    // VIEW B: ALBUMS (DUAL-STATE: GRID <--> ALBUM DETAIL)
                    // =========================================================
                    Item {
                        anchors.fill: parent
                        visible: currentTab === "albums"

                        // STATE 1: ALBUM GRID VIEW
                        ScrollView {
                            anchors.fill: parent
                            anchors.margins: 14
                            visible: selectedAlbum === null
                            clip: true

                            GridView {
                                width: parent.width
                                cellWidth: 190
                                cellHeight: 200
                                model: localBackend.albums

                                delegate: Rectangle {
                                    width: 176
                                    height: 186
                                    radius: localTheme.radius
                                    color: albMouse.containsMouse ? localTheme.surfaceElevated : localTheme.background
                                    border.color: albMouse.containsMouse ? localTheme.accent : localTheme.border
                                    border.width: 1

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 6

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 100
                                            color: localTheme.surface
                                            border.color: localTheme.border
                                            border.width: 1
                                            radius: localTheme.radius

                                            Image {
                                                id: albCoverImg
                                                anchors.fill: parent
                                                anchors.margins: 2
                                                fillMode: Image.PreserveAspectCrop
                                                source: modelData.cover_art_path ? ("file://" + modelData.cover_art_path) : ""
                                                visible: status === Image.Ready
                                            }

                                            Rectangle {
                                                anchors.fill: parent
                                                visible: !modelData.cover_art_path || albCoverImg.status !== Image.Ready
                                                color: localTheme.surfaceElevated
                                                radius: localTheme.radius
                                                border.color: localTheme.border
                                                border.width: 1

                                                ColumnLayout {
                                                    anchors.centerIn: parent
                                                    spacing: 2
                                                    Text {
                                                        Layout.alignment: Qt.AlignHCenter
                                                        text: "💿"
                                                        font.pixelSize: 28
                                                    }
                                                    Text {
                                                        Layout.alignment: Qt.AlignHCenter
                                                        text: modelData.album_artist.length > 0 ? modelData.album_artist.substring(0, 16) : "Album"
                                                        color: localTheme.accent
                                                        font.pixelSize: appFontSize(8)
                                                        font.family: appFontFamily()
                                                        elide: Text.ElideRight
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.title
                                            color: localTheme.text
                                            font.bold: true
                                            font.pixelSize: appFontSize(11)
                                            font.family: appFontFamily()
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.album_artist
                                            color: localTheme.accent
                                            font.pixelSize: appFontSize(10)
                                            font.family: appFontFamily()
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: (modelData.track_count || 1) + " tracks"
                                            color: localTheme.textMuted
                                            font.pixelSize: appFontSize(9)
                                            font.family: appFontFamily()
                                        }
                                    }

                                    MouseArea {
                                        id: albMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            selectedAlbum = modelData;
                                            selectedAlbumTracks = localBackend.getAlbumTracks(modelData.id);
                                        }
                                    }
                                }
                            }
                        }

                        // STATE 2: ALBUM DETAIL VIEW (Tracks list for this album)
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 10
                            visible: selectedAlbum !== null

                            // Album Detail Navigation & Action Header
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12

                                // Back button
                                Rectangle {
                                    Layout.preferredHeight: 26
                                    Layout.preferredWidth: 120
                                    radius: 2
                                    color: backMouse.containsMouse ? localTheme.surfaceElevated : localTheme.background
                                    border.color: localTheme.border
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: "← Back to Albums"
                                        color: localTheme.text
                                        font.pixelSize: appFontSize(10)
                                        font.family: appFontFamily()
                                    }

                                    MouseArea {
                                        id: backMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: selectedAlbum = null
                                    }
                                }

                                // Play Album Button
                                Rectangle {
                                    Layout.preferredHeight: 26
                                    Layout.preferredWidth: 100
                                    radius: 2
                                    color: localTheme.accent

                                    Text {
                                        anchors.centerIn: parent
                                        text: "▶ Play Album"
                                        color: localTheme.background
                                        font.bold: true
                                        font.pixelSize: appFontSize(10)
                                        font.family: appFontFamily()
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (selectedAlbum) localBackend.playAlbum(selectedAlbum.id);
                                        }
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: selectedAlbumTracks.length + " tracks"
                                    color: localTheme.textMuted
                                    font.pixelSize: appFontSize(10)
                                    font.family: appFontFamily()
                                }
                            }

                            // Album Header Box
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 90
                                color: localTheme.background
                                border.color: localTheme.border
                                border.width: 1
                                radius: 2

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 16

                                    // Cover Image / Icon
                                    Rectangle {
                                        Layout.preferredWidth: 66
                                        Layout.preferredHeight: 66
                                        color: localTheme.surface
                                        border.color: localTheme.border
                                        border.width: 1

                                        Image {
                                            id: detailCoverImg
                                            anchors.fill: parent
                                            fillMode: Image.PreserveAspectCrop
                                            source: (selectedAlbum && selectedAlbum.cover_art_path) ? ("file://" + selectedAlbum.cover_art_path) : ""
                                            visible: status === Image.Ready
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: "💿"
                                            font.pixelSize: 32
                                            visible: !selectedAlbum || !selectedAlbum.cover_art_path || detailCoverImg.status !== Image.Ready
                                        }
                                    }

                                    // Metadata Column
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Text {
                                            text: selectedAlbum ? selectedAlbum.title : ""
                                            color: localTheme.text
                                            font.bold: true
                                            font.pixelSize: appFontSize(14)
                                            font.family: appFontFamily()
                                        }

                                        Text {
                                            text: selectedAlbum ? selectedAlbum.album_artist : ""
                                            color: localTheme.accent
                                            font.pixelSize: appFontSize(11)
                                            font.family: appFontFamily()
                                        }

                                        Text {
                                            text: (selectedAlbum && selectedAlbum.genre ? (selectedAlbum.genre + " · ") : "") + (selectedAlbumTracks.length + " Lossless Tracks")
                                            color: localTheme.textMuted
                                            font.pixelSize: appFontSize(10)
                                            font.family: appFontFamily()
                                        }
                                    }
                                }
                            }

                            // Album Tracks List
                            ListView {
                                id: albumTrackList
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                model: selectedAlbumTracks

                                delegate: Rectangle {
                                    width: albumTrackList.width
                                    height: 28
                                    radius: localTheme.radius
                                    color: (localBackend.isPlaying && localBackend.nowPlayingTitle === modelData.title)
                                           ? localTheme.selection
                                           : (albRowMouse.containsMouse ? localTheme.surfaceElevated : "transparent")

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        spacing: 10

                                        Text {
                                            Layout.preferredWidth: 24
                                            text: (index + 1)
                                            color: localTheme.textMuted
                                            font.pixelSize: appFontSize(10)
                                            font.family: appFontFamily()
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.title
                                            color: (localBackend.isPlaying && localBackend.nowPlayingTitle === modelData.title) ? localTheme.statusSuccess : localTheme.text
                                            font.bold: (localBackend.isPlaying && localBackend.nowPlayingTitle === modelData.title)
                                            font.pixelSize: appFontSize(10)
                                            font.family: appFontFamily()
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            Layout.preferredWidth: 140
                                            text: modelData.track_artist
                                            color: localTheme.textMuted
                                            font.pixelSize: appFontSize(10)
                                            font.family: appFontFamily()
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            Layout.preferredWidth: 70
                                            horizontalAlignment: Text.AlignRight
                                            text: {
                                                var totalSec = Math.floor((modelData.duration_ms || 180000) / 1000);
                                                var min = Math.floor(totalSec / 60);
                                                var sec = totalSec % 60;
                                                return min + ":" + (sec < 10 ? "0" : "") + sec;
                                            }
                                            color: localTheme.textMuted
                                            font.pixelSize: appFontSize(10)
                                            font.family: appFontFamily()
                                        }
                                    }

                                    MouseArea {
                                        id: albRowMouse
                                        anchors.fill: parent
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: (mouse) => {
                                            if (mouse.button === Qt.RightButton) {
                                                contextMenu.openMenu(modelData, mouse.x, mouse.y, parent);
                                            } else {
                                                localBackend.playTrack(modelData.file_path, modelData.title, modelData.track_artist);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // =========================================================
                    // VIEW C: SETTINGS (CATEGORIZED ARCHITECTURE)
                    // =========================================================
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10
                        visible: currentTab === "settings"

                        // Settings Categorized Tab Bar
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Repeater {
                                model: [
                                    { id: "appearance", label: "Appearance" },
                                    { id: "audio", label: "Audio" },
                                    { id: "playback", label: "Playback" },
                                    { id: "library", label: "Library" },
                                    { id: "lyrics", label: "Lyrics" },
                                    { id: "advanced", label: "Advanced" }
                                ]

                                Rectangle {
                                    Layout.preferredHeight: 24
                                    Layout.preferredWidth: setTabLabel.implicitWidth + 18
                                    radius: 2
                                    color: currentSettingsTab === modelData.id ? localTheme.accent : (sTabMouse.containsMouse ? localTheme.surfaceElevated : localTheme.background)
                                    border.color: currentSettingsTab === modelData.id ? localTheme.accent : localTheme.border
                                    border.width: 1

                                    Text {
                                        id: setTabLabel
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        color: currentSettingsTab === modelData.id ? localTheme.background : localTheme.text
                                        font.bold: currentSettingsTab === modelData.id
                                        font.pixelSize: appFontSize(10)
                                        font.family: appFontFamily()
                                    }

                                    MouseArea {
                                        id: sTabMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: currentSettingsTab = modelData.id
                                    }
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: "BitPure v1.0 — Arch Linux"
                                color: localTheme.textMuted
                                font.pixelSize: appFontSize(9)
                                font.family: appFontFamily()
                            }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: localTheme.border }

                        // Settings Content Body (ScrollView)
                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                            ColumnLayout {
                                width: parent.width - 12
                                spacing: 14

                                // ---------------------------------------------
                                // CATEGORY 1: APPEARANCE
                                // ---------------------------------------------
                                ColumnLayout {
                                    visible: currentSettingsTab === "appearance"
                                    Layout.fillWidth: true
                                    spacing: 12

                                    // Theme Family & Variant Card
                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: themeCardCol.implicitHeight + 24
                                        color: localTheme.background
                                        border.color: localTheme.border
                                        border.width: 1
                                        radius: 2

                                        ColumnLayout {
                                            id: themeCardCol
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 12

                                            RowLayout {
                                                Layout.fillWidth: true
                                                Text {
                                                    text: "Theme"
                                                    color: localTheme.accent
                                                    font.bold: true
                                                    font.pixelSize: appFontSize(12)
                                                    font.family: appFontFamily()
                                                }
                                                Item { Layout.fillWidth: true }
                                                Text {
                                                    text: localTheme.family + " · " + localTheme.variant
                                                    color: localTheme.textMuted
                                                    font.pixelSize: appFontSize(10)
                                                    font.family: appFontFamily()
                                                }
                                            }

                                            // 1. Theme Family Quick-Selector Pills
                                            RowLayout {
                                                spacing: 6
                                                Layout.fillWidth: true

                                                Text { text: "Family:"; color: localTheme.text; font.pixelSize: appFontSize(10); font.family: appFontFamily() }

                                                Repeater {
                                                    model: localTheme.availableFamilies

                                                    Rectangle {
                                                        Layout.preferredHeight: 24
                                                        Layout.preferredWidth: famText.implicitWidth + 16
                                                        radius: 2
                                                        color: localTheme.family === modelData ? localTheme.accent : (famMouse.containsMouse ? localTheme.surfaceElevated : localTheme.surface)
                                                        border.color: localTheme.family === modelData ? localTheme.accent : localTheme.border
                                                        border.width: 1

                                                        Text {
                                                            id: famText
                                                            anchors.centerIn: parent
                                                            text: modelData
                                                            color: localTheme.family === modelData ? localTheme.background : localTheme.text
                                                            font.bold: localTheme.family === modelData
                                                            font.pixelSize: appFontSize(10)
                                                            font.family: appFontFamily()
                                                        }

                                                        MouseArea {
                                                            id: famMouse
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: localTheme.setFamily(modelData)
                                                        }
                                                    }
                                                }
                                            }

                                            // 2. Theme Variant Quick-Selector Chips
                                            RowLayout {
                                                spacing: 6
                                                Layout.fillWidth: true

                                                Text { text: "Variant:"; color: localTheme.text; font.pixelSize: appFontSize(10); font.family: appFontFamily() }

                                                Flow {
                                                    Layout.fillWidth: true
                                                    spacing: 6

                                                    Repeater {
                                                        model: localTheme.availableVariants

                                                        Rectangle {
                                                            height: 22
                                                            width: varText.implicitWidth + 14
                                                            radius: 2
                                                            color: localTheme.variant === modelData ? localTheme.selection : (varMouse.containsMouse ? localTheme.surfaceElevated : "transparent")
                                                            border.color: localTheme.variant === modelData ? localTheme.accent : localTheme.border
                                                            border.width: 1

                                                            Text {
                                                                id: varText
                                                                anchors.centerIn: parent
                                                                text: modelData
                                                                color: localTheme.variant === modelData ? localTheme.accent : localTheme.textMuted
                                                                font.bold: localTheme.variant === modelData
                                                                font.pixelSize: appFontSize(9)
                                                                font.family: appFontFamily()
                                                            }

                                                            MouseArea {
                                                                id: varMouse
                                                                anchors.fill: parent
                                                                hoverEnabled: true
                                                                cursorShape: Qt.PointingHandCursor
                                                                onClicked: localTheme.setVariant(modelData)
                                                            }
                                                        }
                                                    }
                                                }
                                            }

                                            // 3. Palette Swatch Preview Strip
                                            RowLayout {
                                                spacing: 8
                                                Text { text: "Palette:"; color: localTheme.textMuted; font.pixelSize: appFontSize(9); font.family: appFontFamily() }
                                                Repeater {
                                                    model: [
                                                        { color: localTheme.background, label: "BG" },
                                                        { color: localTheme.surface, label: "Surface" },
                                                        { color: localTheme.surfaceElevated, label: "Elevated" },
                                                        { color: localTheme.border, label: "Border" },
                                                        { color: localTheme.accent, label: "Accent" },
                                                        { color: localTheme.text, label: "Text" },
                                                        { color: localTheme.statusSuccess, label: "Success" }
                                                    ]
                                                    Rectangle {
                                                        width: 38
                                                        height: 18
                                                        radius: 2
                                                        color: modelData.color
                                                        border.color: localTheme.border
                                                        border.width: 1
                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: modelData.label
                                                            color: (index === 0 || index === 1) ? localTheme.textMuted : localTheme.background
                                                            font.pixelSize: 8
                                                            font.family: appFontFamily()
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Font Family & Scaling Card
                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: fontCardCol.implicitHeight + 24
                                        color: localTheme.background
                                        border.color: localTheme.border
                                        border.width: 1
                                        radius: 2

                                        ColumnLayout {
                                            id: fontCardCol
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 10

                                            Text {
                                                text: "Typography & Scaling"
                                                color: localTheme.accent
                                                font.bold: true
                                                font.pixelSize: appFontSize(11)
                                                font.family: appFontFamily()
                                            }

                                            RowLayout {
                                                spacing: 12

                                                Text { text: "Application Font:"; color: localTheme.text; font.pixelSize: appFontSize(10); font.family: appFontFamily() }

                                                ComboBox {
                                                    id: fontCombo
                                                    Layout.preferredWidth: 220
                                                    Layout.preferredHeight: 26
                                                    model: settingsManager.curatedFonts
                                                    currentIndex: Math.max(0, settingsManager.curatedFonts.indexOf(settingsManager.fontFamily))
                                                    onActivated: (idx) => settingsManager.setFontFamily(model[idx])
                                                    background: Rectangle { color: localTheme.surface; border.color: localTheme.border; border.width: 1; radius: 2 }
                                                    contentItem: Text { leftPadding: 8; text: fontCombo.displayText; color: localTheme.text; font.pixelSize: appFontSize(10); font.family: appFontFamily(); verticalAlignment: Text.AlignVCenter }
                                                    delegate: ItemDelegate {
                                                        width: fontCombo.width
                                                        height: 28
                                                        highlighted: fontCombo.highlightedIndex === index
                                                        contentItem: Text {
                                                            leftPadding: 8
                                                            text: modelData || ""
                                                            color: highlighted ? localTheme.accent : localTheme.text
                                                            font.pixelSize: appFontSize(10)
                                                            font.family: modelData === "System Default" ? appFontFamily() : modelData
                                                            verticalAlignment: Text.AlignVCenter
                                                        }
                                                        background: Rectangle {
                                                            color: highlighted ? localTheme.surfaceElevated : localTheme.surface
                                                        }
                                                    }
                                                    popup: Popup {
                                                        y: fontCombo.height + 2
                                                        width: fontCombo.width
                                                        implicitHeight: Math.min(220, contentItem.implicitHeight)
                                                        padding: 1
                                                        contentItem: ListView {
                                                            clip: true
                                                            implicitHeight: contentHeight
                                                            model: fontCombo.popup.visible ? fontCombo.delegateModel : null
                                                            currentIndex: fontCombo.highlightedIndex
                                                            ScrollIndicator.vertical: ScrollIndicator { }
                                                        }
                                                        background: Rectangle {
                                                            color: localTheme.surface
                                                            border.color: localTheme.accent
                                                            border.width: 1
                                                            radius: 2
                                                        }
                                                    }
                                                }

                                                Text {
                                                    text: "Preview: Lossless Audio 96kHz 24-bit"
                                                    color: localTheme.textMuted
                                                    font.pixelSize: appFontSize(10)
                                                    font.family: appFontFamily()
                                                }
                                            }

                                            RowLayout {
                                                spacing: 8

                                                Text { text: "Font Size:"; color: localTheme.text; font.pixelSize: appFontSize(10); font.family: appFontFamily() }

                                                Repeater {
                                                    model: [
                                                        { level: 0, label: "Small (85%)" },
                                                        { level: 1, label: "Default (100%)" },
                                                        { level: 2, label: "Large (115%)" },
                                                        { level: 3, label: "Extra Large (130%)" }
                                                    ]

                                                    Rectangle {
                                                        Layout.preferredHeight: 22
                                                        Layout.preferredWidth: fSizeLabel.implicitWidth + 14
                                                        radius: 2
                                                        color: settingsManager.fontSizeLevel === modelData.level ? localTheme.accent : localTheme.surface
                                                        border.color: settingsManager.fontSizeLevel === modelData.level ? localTheme.accent : localTheme.border
                                                        border.width: 1

                                                        Text {
                                                            id: fSizeLabel
                                                            anchors.centerIn: parent
                                                            text: modelData.label
                                                            color: settingsManager.fontSizeLevel === modelData.level ? localTheme.background : localTheme.text
                                                            font.bold: settingsManager.fontSizeLevel === modelData.level
                                                            font.pixelSize: appFontSize(9)
                                                            font.family: appFontFamily()
                                                        }

                                                        MouseArea {
                                                            anchors.fill: parent
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: settingsManager.setFontSizeLevel(modelData.level)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Motion & Animation Card
                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: animCardCol.implicitHeight + 24
                                        color: localTheme.background
                                        border.color: localTheme.border
                                        border.width: 1
                                        radius: 2

                                        ColumnLayout {
                                            id: animCardCol
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 10

                                            Text {
                                                text: "Animations & Motion"
                                                color: localTheme.accent
                                                font.bold: true
                                                font.pixelSize: appFontSize(11)
                                                font.family: appFontFamily()
                                            }

                                            RowLayout {
                                                spacing: 12

                                                Rectangle {
                                                    Layout.preferredHeight: 24
                                                    Layout.preferredWidth: 160
                                                    radius: 2
                                                    color: settingsManager.reducedMotion ? localTheme.accent : localTheme.surface
                                                    border.color: settingsManager.reducedMotion ? localTheme.accent : localTheme.border
                                                    border.width: 1

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: settingsManager.reducedMotion ? "Reduced Motion: ON" : "Reduced Motion: OFF"
                                                        color: settingsManager.reducedMotion ? localTheme.background : localTheme.text
                                                        font.bold: true
                                                        font.pixelSize: appFontSize(10)
                                                        font.family: appFontFamily()
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: settingsManager.reducedMotion = !settingsManager.reducedMotion
                                                    }
                                                }

                                                Text {
                                                    text: "When ON, disables transitions and switches views instantly."
                                                    color: localTheme.textMuted
                                                    font.pixelSize: appFontSize(10)
                                                    font.family: appFontFamily()
                                                }
                                            }
                                        }
                                    }
                                }

                                // ---------------------------------------------
                                // CATEGORY 2: AUDIO
                                // ---------------------------------------------
                                ColumnLayout {
                                    visible: currentSettingsTab === "audio"
                                    Layout.fillWidth: true
                                    spacing: 12

                                    // Playback Mode Card
                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: audioModeCol.implicitHeight + 24
                                        color: localTheme.background
                                        border.color: localTheme.border
                                        border.width: 1
                                        radius: 2

                                        ColumnLayout {
                                            id: audioModeCol
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 10

                                            Text {
                                                text: "Playback Mode"
                                                color: localTheme.accent
                                                font.bold: true
                                                font.pixelSize: appFontSize(11)
                                                font.family: appFontFamily()
                                            }

                                            RowLayout {
                                                spacing: 10

                                                Rectangle {
                                                    Layout.preferredHeight: 26
                                                    Layout.preferredWidth: 190
                                                    radius: 2
                                                    color: localBackend.isBitPerfect ? localTheme.statusSuccess : localTheme.surface
                                                    border.color: localBackend.isBitPerfect ? localTheme.statusSuccess : localTheme.border
                                                    border.width: 1

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "● Pure Bit-Perfect Mode"
                                                        color: localBackend.isBitPerfect ? localTheme.background : localTheme.text
                                                        font.bold: true
                                                        font.pixelSize: appFontSize(10)
                                                        font.family: appFontFamily()
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: localBackend.isBitPerfect = true
                                                    }
                                                }

                                                Rectangle {
                                                    Layout.preferredHeight: 26
                                                    Layout.preferredWidth: 180
                                                    radius: 2
                                                    color: !localBackend.isBitPerfect ? localTheme.statusWarning : localTheme.surface
                                                    border.color: !localBackend.isBitPerfect ? localTheme.statusWarning : localTheme.border
                                                    border.width: 1

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "Audited DSP Mode (EQ)"
                                                        color: !localBackend.isBitPerfect ? localTheme.background : localTheme.text
                                                        font.bold: true
                                                        font.pixelSize: appFontSize(10)
                                                        font.family: appFontFamily()
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: localBackend.isBitPerfect = false
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Output Device Selector
                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: devCardCol.implicitHeight + 24
                                        color: localTheme.background
                                        border.color: localTheme.border
                                        border.width: 1
                                        radius: 2

                                        ColumnLayout {
                                            id: devCardCol
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 10

                                            Text {
                                                text: "Output Device"
                                                color: localTheme.accent
                                                font.bold: true
                                                font.pixelSize: appFontSize(11)
                                                font.family: appFontFamily()
                                            }

                                            RowLayout {
                                                spacing: 12

                                                Text { text: "Active Device:"; color: localTheme.text; font.pixelSize: appFontSize(10); font.family: appFontFamily() }

                                                ComboBox {
                                                    id: devCombo
                                                    Layout.preferredWidth: 320
                                                    Layout.preferredHeight: 26
                                                    model: localBackend.devices
                                                    textRole: "name"
                                                    currentIndex: {
                                                        for (var i = 0; i < localBackend.devices.length; ++i) {
                                                            if (localBackend.devices[i].id === localBackend.activeDeviceId) return i;
                                                        }
                                                        return 0;
                                                    }
                                                    onActivated: (idx) => localBackend.setActiveDeviceId(localBackend.devices[idx].id)
                                                    background: Rectangle { color: localTheme.surface; border.color: localTheme.border; border.width: 1; radius: 2 }
                                                    contentItem: Text { leftPadding: 8; text: devCombo.displayText; color: localTheme.text; font.pixelSize: appFontSize(10); font.family: appFontFamily(); verticalAlignment: Text.AlignVCenter }
                                                    delegate: ItemDelegate {
                                                        width: devCombo.width
                                                        height: 28
                                                        highlighted: devCombo.highlightedIndex === index
                                                        contentItem: Text {
                                                            leftPadding: 8
                                                            text: modelData.name || ""
                                                            color: highlighted ? localTheme.accent : localTheme.text
                                                            font.pixelSize: appFontSize(10)
                                                            font.family: appFontFamily()
                                                            verticalAlignment: Text.AlignVCenter
                                                        }
                                                        background: Rectangle {
                                                            color: highlighted ? localTheme.surfaceElevated : localTheme.surface
                                                        }
                                                    }
                                                    popup: Popup {
                                                        y: devCombo.height + 2
                                                        width: devCombo.width
                                                        implicitHeight: Math.min(200, contentItem.implicitHeight)
                                                        padding: 1
                                                        contentItem: ListView {
                                                            clip: true
                                                            implicitHeight: contentHeight
                                                            model: devCombo.popup.visible ? devCombo.delegateModel : null
                                                            currentIndex: devCombo.highlightedIndex
                                                        }
                                                        background: Rectangle {
                                                            color: localTheme.surface
                                                            border.color: localTheme.borderHighlight
                                                            border.width: 1
                                                            radius: 2
                                                        }
                                                    }
                                                }

                                                Rectangle {
                                                    Layout.preferredHeight: 22
                                                    Layout.preferredWidth: 64
                                                    color: localTheme.surface
                                                    border.color: localTheme.border
                                                    border.width: 1
                                                    radius: 2

                                                    Text { anchors.centerIn: parent; text: "Refresh"; color: localTheme.textMuted; font.pixelSize: appFontSize(9); font.family: appFontFamily() }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: localBackend.refreshDevices()
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // 10-Band EQ & Preamp
                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: eqCardCol.implicitHeight + 24
                                        color: localTheme.background
                                        border.color: localTheme.border
                                        border.width: 1
                                        radius: 2

                                        ColumnLayout {
                                            id: eqCardCol
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 10

                                            RowLayout {
                                                Layout.fillWidth: true
                                                Text { text: "Equalizer"; color: localTheme.accent; font.bold: true; font.pixelSize: appFontSize(11); font.family: appFontFamily() }
                                                Item { Layout.fillWidth: true }
                                                Rectangle {
                                                    Layout.preferredHeight: 20
                                                    Layout.preferredWidth: 80
                                                    color: localTheme.surface
                                                    border.color: localTheme.border
                                                    border.width: 1
                                                    radius: 2
                                                    Text { anchors.centerIn: parent; text: "↺ Reset 0dB"; color: localTheme.text; font.pixelSize: appFontSize(9); font.family: appFontFamily() }
                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: localBackend.resetEq()
                                                    }
                                                }
                                            }

                                            // Built-in Presets
                                            RowLayout {
                                                spacing: 6
                                                Text { text: "Presets:"; color: localTheme.textMuted; font.pixelSize: appFontSize(10); font.family: appFontFamily() }

                                                Repeater {
                                                    model: ["Flat", "Balanced", "Bass Boost", "Warm Vocal", "Treble Clean"]
                                                    Rectangle {
                                                        Layout.preferredHeight: 20
                                                        Layout.preferredWidth: pTxt.implicitWidth + 10
                                                        radius: 2
                                                        color: localBackend.activeEqPreset === index ? localTheme.accent : localTheme.surface
                                                        border.color: localBackend.activeEqPreset === index ? localTheme.accent : localTheme.border
                                                        border.width: 1
                                                        Text { id: pTxt; anchors.centerIn: parent; text: modelData; color: localBackend.activeEqPreset === index ? localTheme.background : localTheme.text; font.pixelSize: appFontSize(9); font.family: appFontFamily() }
                                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: localBackend.setActiveEqPreset(index) }
                                                    }
                                                }
                                            }

                                            // Custom Presets Rack
                                            RowLayout {
                                                spacing: 6
                                                Layout.fillWidth: true
                                                Text { text: "Custom:"; color: localTheme.textMuted; font.pixelSize: appFontSize(10); font.family: appFontFamily() }

                                                Flow {
                                                    Layout.fillWidth: true
                                                    spacing: 6

                                                    Repeater {
                                                        model: localBackend.customEqPresets
                                                        Rectangle {
                                                            height: 20
                                                            width: cEqRow.implicitWidth + 12
                                                            radius: 2
                                                            color: localTheme.surface
                                                            border.color: localTheme.accent
                                                            border.width: 1

                                                            RowLayout {
                                                                id: cEqRow
                                                                anchors.centerIn: parent
                                                                spacing: 5

                                                                Text {
                                                                    text: modelData.name || "Custom"
                                                                    color: localTheme.text
                                                                    font.pixelSize: appFontSize(9)
                                                                    font.family: appFontFamily()
                                                                }

                                                                Text {
                                                                    text: "×"
                                                                    color: localTheme.statusError
                                                                    font.bold: true
                                                                    font.pixelSize: appFontSize(10)
                                                                    MouseArea {
                                                                        anchors.fill: parent
                                                                        cursorShape: Qt.PointingHandCursor
                                                                        onClicked: localBackend.deleteCustomPreset(index)
                                                                    }
                                                                }
                                                            }

                                                            MouseArea {
                                                                anchors.fill: parent
                                                                cursorShape: Qt.PointingHandCursor
                                                                onClicked: localBackend.applyCustomPreset(index)
                                                            }
                                                        }
                                                    }

                                                    // "+ Save Preset" button
                                                    Rectangle {
                                                        height: 20
                                                        width: saveBtnTxt.implicitWidth + 12
                                                        radius: 2
                                                        color: saveEqPrompt.visible ? localTheme.accent : localTheme.surfaceElevated
                                                        border.color: localTheme.accent
                                                        border.width: 1

                                                        Text {
                                                            id: saveBtnTxt
                                                            anchors.centerIn: parent
                                                            text: "+ Save Preset"
                                                            color: saveEqPrompt.visible ? localTheme.background : localTheme.accent
                                                            font.bold: true
                                                            font.pixelSize: appFontSize(9)
                                                            font.family: appFontFamily()
                                                        }

                                                        MouseArea {
                                                            anchors.fill: parent
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: {
                                                                saveEqPrompt.visible = !saveEqPrompt.visible;
                                                                if (saveEqPrompt.visible) customEqInput.forceActiveFocus();
                                                            }
                                                        }
                                                    }
                                                }
                                            }

                                            // Inline input for saving custom preset
                                            RowLayout {
                                                id: saveEqPrompt
                                                visible: false
                                                spacing: 8
                                                Layout.fillWidth: true

                                                Text { text: "Preset Name:"; color: localTheme.text; font.pixelSize: appFontSize(10); font.family: appFontFamily() }

                                                Rectangle {
                                                    Layout.preferredWidth: 180
                                                    Layout.preferredHeight: 22
                                                    color: localTheme.surface
                                                    border.color: localTheme.accent
                                                    border.width: 1
                                                    radius: 2

                                                    TextInput {
                                                        id: customEqInput
                                                        anchors.fill: parent
                                                        anchors.margins: 4
                                                        color: localTheme.text
                                                        font.pixelSize: appFontSize(10)
                                                        font.family: appFontFamily()
                                                        selectByMouse: true
                                                        Keys.onReturnPressed: saveCustomBtn.triggerSave()
                                                    }
                                                }

                                                Rectangle {
                                                    id: saveCustomBtn
                                                    Layout.preferredHeight: 22
                                                    Layout.preferredWidth: 50
                                                    color: localTheme.accent
                                                    radius: 2

                                                    function triggerSave() {
                                                        var name = customEqInput.text.trim();
                                                        if (name.length > 0) {
                                                            localBackend.saveCustomPreset(name);
                                                            customEqInput.text = "";
                                                            saveEqPrompt.visible = false;
                                                        }
                                                    }

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "Save"
                                                        color: localTheme.background
                                                        font.bold: true
                                                        font.pixelSize: appFontSize(9)
                                                        font.family: appFontFamily()
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: saveCustomBtn.triggerSave()
                                                    }
                                                }

                                                Rectangle {
                                                    Layout.preferredHeight: 22
                                                    Layout.preferredWidth: 50
                                                    color: localTheme.surface
                                                    border.color: localTheme.border
                                                    border.width: 1
                                                    radius: 2

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "Cancel"
                                                        color: localTheme.textMuted
                                                        font.pixelSize: appFontSize(9)
                                                        font.family: appFontFamily()
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            customEqInput.text = "";
                                                            saveEqPrompt.visible = false;
                                                        }
                                                    }
                                                }
                                            }

                                            // Preamp Slider
                                            RowLayout {
                                                spacing: 12
                                                Text { text: "Preamp Gain:"; color: localTheme.text; font.pixelSize: appFontSize(10); font.family: appFontFamily() }
                                                Slider {
                                                    id: preampSlider
                                                    Layout.preferredWidth: 200
                                                    from: -12.0
                                                    to: 12.0
                                                    value: localBackend.preamp
                                                    stepSize: 0.5
                                                    onMoved: localBackend.setPreamp(value)
                                                }
                                                Text { text: (localBackend.preamp > 0 ? "+" : "") + localBackend.preamp.toFixed(1) + " dB"; color: localTheme.accent; font.bold: true; font.pixelSize: appFontSize(10); font.family: appFontFamily() }
                                            }

                                            // 10 Band Sliders
                                            RowLayout {
                                                spacing: 8
                                                Layout.fillWidth: true

                                                Repeater {
                                                    model: [
                                                        { label: "31Hz", band: 0 },
                                                        { label: "62Hz", band: 1 },
                                                        { label: "125Hz", band: 2 },
                                                        { label: "250Hz", band: 3 },
                                                        { label: "500Hz", band: 4 },
                                                        { label: "1kHz", band: 5 },
                                                        { label: "2kHz", band: 6 },
                                                        { label: "4kHz", band: 7 },
                                                        { label: "8kHz", band: 8 },
                                                        { label: "16kHz", band: 9 }
                                                    ]

                                                    ColumnLayout {
                                                        Layout.fillWidth: true
                                                        spacing: 4

                                                        Text {
                                                            Layout.alignment: Qt.AlignHCenter
                                                            text: (localBackend.eqGains[modelData.band] || 0) > 0 ? ("+" + localBackend.eqGains[modelData.band].toFixed(1)) : (localBackend.eqGains[modelData.band] || 0).toFixed(1)
                                                            color: localTheme.accent
                                                            font.pixelSize: appFontSize(9)
                                                            font.family: appFontFamily()
                                                        }

                                                        Slider {
                                                            Layout.alignment: Qt.AlignHCenter
                                                            Layout.preferredHeight: 110
                                                            orientation: Qt.Vertical
                                                            from: -12.0
                                                            to: 12.0
                                                            value: localBackend.eqGains[modelData.band] || 0
                                                            stepSize: 0.5
                                                            onMoved: localBackend.setEqBand(modelData.band, value)
                                                        }

                                                        Text {
                                                            Layout.alignment: Qt.AlignHCenter
                                                            text: modelData.label
                                                            color: localTheme.textMuted
                                                            font.pixelSize: appFontSize(9)
                                                            font.family: appFontFamily()
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // ---------------------------------------------
                                // CATEGORY 3: PLAYBACK
                                // ---------------------------------------------
                                ColumnLayout {
                                    visible: currentSettingsTab === "playback"
                                    Layout.fillWidth: true
                                    spacing: 12

                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: pbCardCol.implicitHeight + 24
                                        color: localTheme.background
                                        border.color: localTheme.border
                                        border.width: 1
                                        radius: 2

                                        ColumnLayout {
                                            id: pbCardCol
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 12

                                            Text {
                                                text: "Playback Behaviors"
                                                color: localTheme.accent
                                                font.bold: true
                                                font.pixelSize: appFontSize(11)
                                                font.family: appFontFamily()
                                            }

                                            // Shuffle Behavior
                                            RowLayout {
                                                spacing: 8
                                                Text { text: "Shuffle Mode:"; color: localTheme.text; font.pixelSize: appFontSize(10); font.family: appFontFamily() }

                                                Repeater {
                                                    model: [
                                                        { mode: 0, label: "Sequential (Off)" },
                                                        { mode: 1, label: "Normal Shuffle" },
                                                        { mode: 2, label: "✨ Smart Shuffle (Biased to Liked)" }
                                                    ]

                                                    Rectangle {
                                                        Layout.preferredHeight: 22
                                                        Layout.preferredWidth: shufModeLbl.implicitWidth + 14
                                                        radius: 2
                                                        color: localBackend.shuffleMode === modelData.mode ? localTheme.accent : localTheme.surface
                                                        border.color: localBackend.shuffleMode === modelData.mode ? localTheme.accent : localTheme.border
                                                        border.width: 1

                                                        Text {
                                                            id: shufModeLbl
                                                            anchors.centerIn: parent
                                                            text: modelData.label
                                                            color: localBackend.shuffleMode === modelData.mode ? localTheme.background : localTheme.text
                                                            font.bold: localBackend.shuffleMode === modelData.mode
                                                            font.pixelSize: appFontSize(9)
                                                            font.family: appFontFamily()
                                                        }

                                                        MouseArea {
                                                            anchors.fill: parent
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: localBackend.setShuffleMode(modelData.mode)
                                                        }
                                                    }
                                                }
                                            }

                                            // Repeat Behavior
                                            RowLayout {
                                                spacing: 8
                                                Text { text: "Repeat Mode:"; color: localTheme.text; font.pixelSize: appFontSize(10); font.family: appFontFamily() }

                                                Repeater {
                                                    model: [
                                                        { mode: 0, label: "Off" },
                                                        { mode: 1, label: "🔁 Repeat All" },
                                                        { mode: 2, label: "🔂 Repeat One" }
                                                    ]

                                                    Rectangle {
                                                        Layout.preferredHeight: 22
                                                        Layout.preferredWidth: repModeLbl.implicitWidth + 14
                                                        radius: 2
                                                        color: localBackend.repeatMode === modelData.mode ? localTheme.statusSuccess : localTheme.surface
                                                        border.color: localBackend.repeatMode === modelData.mode ? localTheme.statusSuccess : localTheme.border
                                                        border.width: 1

                                                        Text {
                                                            id: repModeLbl
                                                            anchors.centerIn: parent
                                                            text: modelData.label
                                                            color: localBackend.repeatMode === modelData.mode ? localTheme.background : localTheme.text
                                                            font.bold: localBackend.repeatMode === modelData.mode
                                                            font.pixelSize: appFontSize(9)
                                                            font.family: appFontFamily()
                                                        }

                                                        MouseArea {
                                                            anchors.fill: parent
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: localBackend.setRepeatMode(modelData.mode)
                                                        }
                                                    }
                                                }
                                            }

                                            // Auto Advance
                                            RowLayout {
                                                spacing: 8
                                                Text { text: "Auto-Advance:"; color: localTheme.text; font.pixelSize: appFontSize(10); font.family: appFontFamily() }
                                                Text { text: "Active (Seamless continuous playback via MPV EOF detection)"; color: localTheme.statusSuccess; font.pixelSize: appFontSize(10); font.family: appFontFamily() }
                                            }
                                        }
                                    }
                                }

                                // ---------------------------------------------
                                // CATEGORY 4: LIBRARY
                                // ---------------------------------------------
                                ColumnLayout {
                                    visible: currentSettingsTab === "library"
                                    Layout.fillWidth: true
                                    spacing: 12

                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: libCardCol.implicitHeight + 24
                                        color: localTheme.background
                                        border.color: localTheme.border
                                        border.width: 1
                                        radius: 2

                                        ColumnLayout {
                                            id: libCardCol
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 12

                                            Text {
                                                text: "Library & Folder Management"
                                                color: localTheme.accent
                                                font.bold: true
                                                font.pixelSize: appFontSize(11)
                                                font.family: appFontFamily()
                                            }

                                            RowLayout {
                                                spacing: 10
                                                Text { text: "Music Folder:"; color: localTheme.text; font.pixelSize: appFontSize(10); font.family: appFontFamily() }
                                                Text { text: localBackend.musicFolder; color: localTheme.accent; font.bold: true; font.pixelSize: appFontSize(10); font.family: appFontFamily() }
                                            }

                                            RowLayout {
                                                spacing: 12

                                                Rectangle {
                                                    Layout.preferredHeight: 26
                                                    Layout.preferredWidth: 140
                                                    radius: 2
                                                    color: localTheme.surface
                                                    border.color: localTheme.accent
                                                    border.width: 1

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "⟳ Rescan Library"
                                                        color: localTheme.accent
                                                        font.bold: true
                                                        font.pixelSize: appFontSize(10)
                                                        font.family: appFontFamily()
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: localBackend.rescanLibrary()
                                                    }
                                                }

                                                Text {
                                                    text: "Indexed: " + localBackend.tracks.length + " Tracks across " + localBackend.albums.length + " Albums"
                                                    color: localTheme.textMuted
                                                    font.pixelSize: appFontSize(10)
                                                    font.family: appFontFamily()
                                                }
                                            }
                                        }
                                    }
                                }

                                // ---------------------------------------------
                                // CATEGORY 5: LYRICS
                                // ---------------------------------------------
                                ColumnLayout {
                                    visible: currentSettingsTab === "lyrics"
                                    Layout.fillWidth: true
                                    spacing: 12

                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: lyrCardCol.implicitHeight + 24
                                        color: localTheme.background
                                        border.color: localTheme.border
                                        border.width: 1
                                        radius: 2

                                        ColumnLayout {
                                            id: lyrCardCol
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 12

                                            Text {
                                                text: "Lyrics Providers & Translation"
                                                color: localTheme.accent
                                                font.bold: true
                                                font.pixelSize: appFontSize(11)
                                                font.family: appFontFamily()
                                            }

                                            RowLayout {
                                                spacing: 12

                                                Rectangle {
                                                    Layout.preferredHeight: 26
                                                    Layout.preferredWidth: 180
                                                    radius: 2
                                                    color: localBackend.lyricsTranslationEnabled ? localTheme.accent : localTheme.surface
                                                    border.color: localBackend.lyricsTranslationEnabled ? localTheme.accent : localTheme.border
                                                    border.width: 1

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: localBackend.lyricsTranslationEnabled ? "Translation: ENABLED" : "Translation: DISABLED"
                                                        color: localBackend.lyricsTranslationEnabled ? localTheme.background : localTheme.text
                                                        font.bold: true
                                                        font.pixelSize: appFontSize(10)
                                                        font.family: appFontFamily()
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: localBackend.lyricsTranslationEnabled = !localBackend.lyricsTranslationEnabled
                                                    }
                                                }

                                                Text {
                                                    text: "Target: English (en) · Cached in ~/.config/bitpure/lyrics_cache.json"
                                                    color: localTheme.textMuted
                                                    font.pixelSize: appFontSize(10)
                                                    font.family: appFontFamily()
                                                }
                                            }

                                            Text {
                                                text: "Priority 1: Local .lrc file in audio directory (bit-perfect offline sync)\nPriority 2: LRCLIB public API (online fallback)"
                                                color: localTheme.textMuted
                                                font.pixelSize: appFontSize(10)
                                                font.family: appFontFamily()
                                                lineHeight: 1.4
                                            }
                                        }
                                    }
                                }

                                // ---------------------------------------------
                                // CATEGORY 6: ADVANCED (Process Stats & Reset Settings)
                                // ---------------------------------------------
                                ColumnLayout {
                                    visible: currentSettingsTab === "advanced"
                                    Layout.fillWidth: true
                                    spacing: 12

                                    // Process Metrics Card
                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: advMetricsCol.implicitHeight + 24
                                        color: localTheme.background
                                        border.color: localTheme.border
                                        border.width: 1
                                        radius: 2

                                        ColumnLayout {
                                            id: advMetricsCol
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 8

                                            Text {
                                                text: "Process Telemetry & Diagnostics"
                                                color: localTheme.accent
                                                font.bold: true
                                                font.pixelSize: appFontSize(11)
                                                font.family: appFontFamily()
                                            }

                                            Text {
                                                text: "Player Footprint: " + systemMonitor.formattedStatus
                                                color: localTheme.text
                                                font.pixelSize: appFontSize(10)
                                                font.family: appFontFamily()
                                            }

                                            Text {
                                                text: "System Clock: " + systemMonitor.currentTimeStr
                                                color: localTheme.textMuted
                                                font.pixelSize: appFontSize(10)
                                                font.family: appFontFamily()
                                            }
                                        }
                                    }

                                    // Reset All Settings Card
                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: resetCardCol.implicitHeight + 24
                                        color: localTheme.background
                                        border.color: localTheme.statusError
                                        border.width: 1
                                        radius: 2

                                        ColumnLayout {
                                            id: resetCardCol
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 10

                                            Text {
                                                text: "Reset All Preferences"
                                                color: localTheme.statusError
                                                font.bold: true
                                                font.pixelSize: appFontSize(11)
                                                font.family: appFontFamily()
                                            }

                                            Text {
                                                text: "Restore theme, fonts, font size, audio, equalizer, playback and lyrics preferences to default values. Music files, playlists, and listening history will NOT be deleted."
                                                color: localTheme.textMuted
                                                font.pixelSize: appFontSize(10)
                                                font.family: appFontFamily()
                                                wrapMode: Text.Wrap
                                                Layout.fillWidth: true
                                            }

                                            Rectangle {
                                                Layout.preferredHeight: 28
                                                Layout.preferredWidth: 180
                                                color: localTheme.statusError
                                                radius: 2

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "↺ Reset All Settings"
                                                    color: localTheme.background
                                                    font.bold: true
                                                    font.pixelSize: appFontSize(10)
                                                    font.family: appFontFamily()
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: resetConfirmPopup.open()
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
        }

        // =====================================================================
        // 4. BOTTOM STATUS BAR: [NORMAL] | [Signal Integrity] | [System Monitor & Clock]
        // =====================================================================
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 24
            spacing: 12

            // VIM MODE PILL BADGE: [NORMAL / PLAYING]
            Rectangle {
                Layout.preferredHeight: 20
                Layout.preferredWidth: modeText.implicitWidth + 14
                radius: 3
                color: localTheme.background
                border.color: localTheme.accent
                border.width: 1

                Text {
                    id: modeText
                    anchors.centerIn: parent
                    text: localBackend.isPlaying ? "PLAYING" : "NORMAL"
                    color: localTheme.accent
                    font.bold: true
                    font.pixelSize: appFontSize(10)
                    font.family: appFontFamily()
                }
            }

            // SIGNAL PATH STATUS BADGE
            Text {
                text: localBackend.isBitPerfect ? "[PURE 0dB: BIT-PERFECT DIRECT]" : "[AUDITED DSP ACTIVE]"
                color: localBackend.isBitPerfect ? localTheme.statusSuccess : localTheme.statusWarning
                font.bold: true
                font.pixelSize: appFontSize(10)
                font.family: appFontFamily()
            }

            Text {
                text: localBackend.tracks.length + " tracks"
                color: localTheme.textMuted
                font.pixelSize: appFontSize(10)
                font.family: appFontFamily()
            }

            Item { Layout.fillWidth: true }

            // BOTTOM-RIGHT SYSTEM STATUS & 12-HOUR CLOCK
            RowLayout {
                spacing: 10
                Layout.alignment: Qt.AlignVCenter

                Text {
                    text: systemMonitor.formattedStatus
                    color: localTheme.textMuted
                    font.pixelSize: appFontSize(10)
                    font.family: appFontFamily()
                }

                Rectangle {
                    width: 1
                    height: 12
                    color: localTheme.border
                }

                Text {
                    text: systemMonitor.currentTimeStr
                    color: localTheme.accent
                    font.bold: true
                    font.pixelSize: appFontSize(10)
                    font.family: appFontFamily()
                }
            }
        }
    }

    // =========================================================================
    // POPUPS & DIALOGS: Context Menu, Playlist Picker, Confirm Deletion, Reset Settings
    // =========================================================================

    // 1. Right-Click Context Menu
    Popup {
        id: contextMenu
        width: 220
        padding: 6
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Rectangle {
            color: localTheme.background
            border.color: localTheme.accent
            border.width: 1
            radius: 2
        }

        property var targetTrack: null

        function openMenu(track, mouseX, mouseY, sourceItem) {
            targetTrack = track;
            var pos = sourceItem.mapToItem(root.contentItem, mouseX, mouseY);
            x = Math.max(10, Math.min(pos.x, root.width - width - 10));
            y = Math.max(10, Math.min(pos.y, root.height - implicitHeight - 10));
            open();
        }

        contentItem: ColumnLayout {
            spacing: 3

            // Track Header
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 22
                color: localTheme.surface
                radius: 2
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    Text {
                        Layout.fillWidth: true
                        text: contextMenu.targetTrack ? (contextMenu.targetTrack.title + " — " + contextMenu.targetTrack.track_artist) : ""
                        color: localTheme.accent
                        font.bold: true
                        font.pixelSize: appFontSize(9)
                        font.family: appFontFamily()
                        elide: Text.ElideRight
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: localTheme.border }

            // Liked Song Toggle
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                color: likeHover.containsMouse ? localTheme.surface : "transparent"
                radius: 2
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 6; spacing: 6
                    Text {
                        text: (contextMenu.targetTrack && localBackend.isTrackLiked(contextMenu.targetTrack.file_path)) ? "♥" : "♡"
                        color: localTheme.statusError
                        font.pixelSize: appFontSize(11)
                    }
                    Text {
                        text: (contextMenu.targetTrack && localBackend.isTrackLiked(contextMenu.targetTrack.file_path)) ? "Remove from Liked" : "Add to Liked Songs"
                        color: localTheme.text
                        font.pixelSize: appFontSize(10)
                        font.family: appFontFamily()
                    }
                }
                MouseArea {
                    id: likeHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (contextMenu.targetTrack) {
                            localBackend.toggleLikeTrack(contextMenu.targetTrack.file_path);
                        }
                        contextMenu.close();
                    }
                }
            }

            // Add to Queue
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                color: queueHover.containsMouse ? localTheme.surface : "transparent"
                radius: 2
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 6; spacing: 6
                    Text { text: "+"; color: localTheme.statusSuccess; font.pixelSize: appFontSize(11); font.family: appFontFamily() }
                    Text { text: "Add to Queue"; color: localTheme.text; font.pixelSize: appFontSize(10); font.family: appFontFamily() }
                }
                MouseArea {
                    id: queueHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (contextMenu.targetTrack) {
                            localBackend.addToQueue(contextMenu.targetTrack.file_path);
                        }
                        contextMenu.close();
                    }
                }
            }

            // Add to Playlist
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                color: plHover.containsMouse ? localTheme.surface : "transparent"
                radius: 2
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6; spacing: 6
                    Text { text: "📁"; font.pixelSize: appFontSize(10) }
                    Text { text: "Add to Playlist"; color: localTheme.text; font.pixelSize: appFontSize(10); font.family: appFontFamily() }
                    Item { Layout.fillWidth: true }
                    Text { text: "▸"; color: localTheme.textMuted; font.pixelSize: appFontSize(10) }
                }
                MouseArea {
                    id: plHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        playlistPickerPopup.openPicker(contextMenu.targetTrack, contextMenu.x + contextMenu.width + 4, contextMenu.y);
                        contextMenu.close();
                    }
                }
            }

            // Delete from Playlist (visible on playlists tab)
            Rectangle {
                visible: currentTab === "playlists"
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                color: delPlHover.containsMouse ? localTheme.surface : "transparent"
                radius: 2
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 6; spacing: 6
                    Text { text: "−"; color: localTheme.orange; font.bold: true; font.pixelSize: appFontSize(11); font.family: appFontFamily() }
                    Text { text: "Delete from Playlist"; color: localTheme.orange; font.pixelSize: appFontSize(10); font.family: appFontFamily() }
                }
                MouseArea {
                    id: delPlHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (contextMenu.targetTrack && localBackend.activePlaylistName !== "") {
                            localBackend.removeFromPlaylist(localBackend.activePlaylistName, contextMenu.targetTrack.file_path);
                        }
                        contextMenu.close();
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: localTheme.border }

            // Delete Permanently
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                color: delPermHover.containsMouse ? localTheme.surface : "transparent"
                radius: 2
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 6; spacing: 6
                    Text { text: "🗑"; color: localTheme.statusError; font.pixelSize: appFontSize(11) }
                    Text { text: "Delete permanently"; color: localTheme.statusError; font.pixelSize: appFontSize(10); font.family: appFontFamily() }
                }
                MouseArea {
                    id: delPermHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        confirmDeleteDialog.openConfirmation(contextMenu.targetTrack);
                        contextMenu.close();
                    }
                }
            }
        }
    }

    // 2. Playlist Picker Popup
    Popup {
        id: playlistPickerPopup
        width: 180
        padding: 6
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Rectangle {
            color: localTheme.background
            border.color: localTheme.accent
            border.width: 1
            radius: 2
        }

        property var targetTrack: null

        function openPicker(track, posX, posY) {
            targetTrack = track;
            x = Math.max(10, Math.min(posX, root.width - width - 10));
            y = Math.max(10, Math.min(posY, root.height - implicitHeight - 10));
            open();
        }

        contentItem: ColumnLayout {
            spacing: 4

            Text {
                text: "ADD TO PLAYLIST:"
                color: localTheme.textMuted
                font.bold: true
                font.pixelSize: appFontSize(9)
                font.family: appFontFamily()
            }

            Repeater {
                model: localBackend.playlistNames
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 22
                    color: plItemMouse.containsMouse ? localTheme.surface : "transparent"
                    radius: 2
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 6; spacing: 6
                        Text { text: "•"; color: localTheme.accent; font.pixelSize: appFontSize(10) }
                        Text { text: modelData; color: localTheme.text; font.pixelSize: appFontSize(10); font.family: appFontFamily(); elide: Text.ElideRight }
                    }
                    MouseArea {
                        id: plItemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (playlistPickerPopup.targetTrack) {
                                localBackend.addToPlaylist(modelData, playlistPickerPopup.targetTrack.file_path);
                            }
                            playlistPickerPopup.close();
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: localTheme.border }

            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 22
                    color: localTheme.surface
                    border.color: localTheme.border
                    border.width: 1
                    radius: 2
                    TextInput {
                        id: quickPlInput
                        anchors.fill: parent
                        anchors.margins: 4
                        color: localTheme.text
                        font.pixelSize: appFontSize(9)
                        font.family: appFontFamily()
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "New playlist…"
                        color: localTheme.textMuted
                        font.pixelSize: appFontSize(9)
                        font.family: appFontFamily()
                        visible: quickPlInput.text === ""
                    }
                }
                Rectangle {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 22
                    color: localTheme.background
                    border.color: localTheme.accent
                    border.width: 1
                    radius: 2
                    Text { anchors.centerIn: parent; text: "Add"; color: localTheme.accent; font.pixelSize: appFontSize(9); font.family: appFontFamily() }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (quickPlInput.text.trim() !== "") {
                                var plName = quickPlInput.text.trim();
                                localBackend.createPlaylist(plName);
                                if (playlistPickerPopup.targetTrack) {
                                    localBackend.addToPlaylist(plName, playlistPickerPopup.targetTrack.file_path);
                                }
                                quickPlInput.text = "";
                                playlistPickerPopup.close();
                            }
                        }
                    }
                }
            }
        }
    }

    // 3. Confirm Deletion Modal
    Popup {
        id: confirmDeleteDialog
        anchors.centerIn: parent
        width: 380
        padding: 14
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape
        background: Rectangle {
            color: localTheme.background
            border.color: localTheme.statusError
            border.width: 2
            radius: 4
        }

        property var trackToDelete: null

        function openConfirmation(track) {
            trackToDelete = track;
            open();
        }

        contentItem: ColumnLayout {
            spacing: 10

            Text {
                text: "⚠ Confirm Permanent Deletion"
                color: localTheme.statusError
                font.bold: true
                font.pixelSize: appFontSize(12)
                font.family: appFontFamily()
            }

            Text {
                Layout.fillWidth: true
                text: "This action will permanently delete the audio file from your storage disk. This CANNOT be undone."
                color: localTheme.text
                font.pixelSize: appFontSize(10)
                font.family: appFontFamily()
                wrapMode: Text.Wrap
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: colTrkInfo.implicitHeight + 12
                color: localTheme.surface
                border.color: localTheme.border
                border.width: 1
                radius: 2

                ColumnLayout {
                    id: colTrkInfo
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4

                    Text {
                        text: confirmDeleteDialog.trackToDelete ? (confirmDeleteDialog.trackToDelete.title + " — " + confirmDeleteDialog.trackToDelete.track_artist) : ""
                        color: localTheme.statusWarning
                        font.bold: true
                        font.pixelSize: appFontSize(11)
                        font.family: appFontFamily()
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: confirmDeleteDialog.trackToDelete ? confirmDeleteDialog.trackToDelete.file_path : ""
                        color: localTheme.textMuted
                        font.pixelSize: appFontSize(9)
                        font.family: appFontFamily()
                        elide: Text.ElideMiddle
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignRight
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 26
                    color: localTheme.surface
                    border.color: localTheme.border
                    border.width: 1
                    radius: 2
                    Text { anchors.centerIn: parent; text: "Cancel"; color: localTheme.text; font.pixelSize: appFontSize(10); font.family: appFontFamily() }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: confirmDeleteDialog.close() }
                }

                Rectangle {
                    Layout.preferredWidth: 150
                    Layout.preferredHeight: 26
                    color: localTheme.statusError
                    radius: 2
                    Text { anchors.centerIn: parent; text: "Delete Permanently"; color: localTheme.background; font.bold: true; font.pixelSize: appFontSize(10); font.family: appFontFamily() }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (confirmDeleteDialog.trackToDelete) {
                                localBackend.deleteTrackFromStorage(confirmDeleteDialog.trackToDelete.file_path);
                            }
                            confirmDeleteDialog.close();
                        }
                    }
                }
            }
        }
    }

    // 4. Create New Playlist Dialog
    Popup {
        id: newPlaylistDialog
        anchors.centerIn: parent
        width: 280
        padding: 12
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape
        background: Rectangle {
            color: localTheme.background
            border.color: localTheme.accent
            border.width: 1
            radius: 2
        }

        contentItem: ColumnLayout {
            spacing: 8
            Text {
                text: "Create New Playlist"
                color: localTheme.text
                font.bold: true
                font.pixelSize: appFontSize(11)
                font.family: appFontFamily()
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 26
                color: localTheme.surface
                border.color: localTheme.border
                border.width: 1
                radius: 2
                TextInput {
                    id: plNameInput
                    anchors.fill: parent
                    anchors.margins: 4
                    color: localTheme.text
                    font.pixelSize: appFontSize(10)
                    font.family: appFontFamily()
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignRight
                spacing: 8
                Rectangle {
                    Layout.preferredWidth: 60
                    Layout.preferredHeight: 24
                    color: localTheme.surface
                    radius: 2
                    Text { anchors.centerIn: parent; text: "Cancel"; color: localTheme.text; font.pixelSize: appFontSize(9); font.family: appFontFamily() }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: newPlaylistDialog.close() }
                }
                Rectangle {
                    Layout.preferredWidth: 60
                    Layout.preferredHeight: 24
                    color: localTheme.accent
                    radius: 2
                    Text { anchors.centerIn: parent; text: "Create"; color: localTheme.background; font.bold: true; font.pixelSize: appFontSize(9); font.family: appFontFamily() }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (plNameInput.text.trim() !== "") {
                                localBackend.createPlaylist(plNameInput.text.trim());
                                plNameInput.text = "";
                                newPlaylistDialog.close();
                            }
                        }
                    }
                }
            }
        }
    }

    // 5. Reset All Settings Confirmation Dialog
    Popup {
        id: resetConfirmPopup
        anchors.centerIn: parent
        width: 420
        padding: 16
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape
        background: Rectangle {
            color: localTheme.background
            border.color: localTheme.statusError
            border.width: 2
            radius: 4
        }

        contentItem: ColumnLayout {
            spacing: 12

            Text {
                text: "⚠ Reset All Settings to Defaults?"
                color: localTheme.statusError
                font.bold: true
                font.pixelSize: appFontSize(13)
                font.family: appFontFamily()
            }

            Text {
                Layout.fillWidth: true
                text: "This will restore all application preferences (theme, theme variant, font, font size, audio, equalizer, playback behaviors, and lyrics settings) to their original default values.\n\nYour music files, library database, playlists, and listening history will NOT be deleted or modified."
                color: localTheme.text
                font.pixelSize: appFontSize(10)
                font.family: appFontFamily()
                wrapMode: Text.Wrap
                lineHeight: 1.4
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignRight
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 28
                    color: localTheme.surface
                    border.color: localTheme.border
                    border.width: 1
                    radius: 2
                    Text {
                        anchors.centerIn: parent
                        text: "Cancel"
                        color: localTheme.text
                        font.pixelSize: appFontSize(10)
                        font.family: appFontFamily()
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: resetConfirmPopup.close()
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 150
                    Layout.preferredHeight: 28
                    color: localTheme.statusError
                    radius: 2
                    Text {
                        anchors.centerIn: parent
                        text: "Reset All Settings"
                        color: localTheme.background
                        font.bold: true
                        font.pixelSize: appFontSize(10)
                        font.family: appFontFamily()
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            settingsManager.resetAllSettings();
                            resetConfirmPopup.close();
                        }
                    }
                }
            }
        }
    }
}
