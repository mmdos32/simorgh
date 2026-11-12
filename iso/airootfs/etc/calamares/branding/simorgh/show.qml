/* Simorgh slideshow for Calamares.
 *
 * Text colors are set explicitly on every Text element: the slides
 * sit on the light main pane from stylesheet.qss, so dark text is
 * required (the default QML text color would be unreadable on a
 * dark background, and vice versa). The logo sits on a dark chip
 * (sidebar color #0d1418): the pale phoenix is low-contrast
 * straight on the light pane.
 */

import QtQuick 2.0;
import calamares.slideshow 1.0;

Presentation
{
    id: presentation

    function nextSlide() {
        presentation.goToNextSlide();
    }

    Timer {
        id: advanceTimer
        interval: 9000
        running: presentation.activatedInCalamares
        repeat: true
        onTriggered: nextSlide()
    }

    Slide {
        Column {
            anchors.centerIn: parent
            spacing: 18
            width: presentation.width * 0.8

            Rectangle {
                width: 244
                height: 244
                radius: 20
                color: "#0d1418"
                anchors.horizontalCenter: parent.horizontalCenter

                Image {
                    source: "logo.png"
                    width: 220
                    height: 220
                    fillMode: Image.PreserveAspectFit
                    anchors.centerIn: parent
                }
            }
            Text {
                text: qsTr("Welcome to Simorgh")
                font.pixelSize: 26
                font.family: "Inter"
                font.bold: true
                color: "#0d1418"
                horizontalAlignment: Text.AlignHCenter
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
                text: qsTr("A minimal, modern Arch Linux desktop with a glassy Hyprland look. While the installer works, here is what is waiting for you. On Wi-Fi? Press Super+W to join a network first — the installer needs internet.")
                font.pixelSize: 15
                font.family: "Inter"
                color: "#334155"
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
            }
        }
    }

    Slide {
        Column {
            anchors.centerIn: parent
            spacing: 18
            width: presentation.width * 0.8

            Rectangle {
                width: 244
                height: 244
                radius: 20
                color: "#0d1418"
                anchors.horizontalCenter: parent.horizontalCenter

                Image {
                    source: "logo.png"
                    width: 220
                    height: 220
                    fillMode: Image.PreserveAspectFit
                    anchors.centerIn: parent
                }
            }
            Text {
                text: qsTr("A modern Hyprland desktop")
                font.pixelSize: 26
                font.family: "Inter"
                font.bold: true
                color: "#0d1418"
                horizontalAlignment: Text.AlignHCenter
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
                text: qsTr("Tiling windows, a glassy Waybar, and six switchable themes — teal-glass is the default. Everything is keyboard-driven: press Super+K anytime to see all shortcuts. Wi-Fi: press Super+W for Wi-Fi (nmtui).")
                font.pixelSize: 15
                font.family: "Inter"
                color: "#334155"
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
            }
        }
    }

    Slide {
        Column {
            anchors.centerIn: parent
            spacing: 18
            width: presentation.width * 0.8

            Rectangle {
                width: 244
                height: 244
                radius: 20
                color: "#0d1418"
                anchors.horizontalCenter: parent.horizontalCenter

                Image {
                    source: "logo.png"
                    width: 220
                    height: 220
                    fillMode: Image.PreserveAspectFit
                    anchors.centerIn: parent
                }
            }
            Text {
                text: qsTr("Ready to work — and play")
                font.pixelSize: 26
                font.family: "Inter"
                font.bold: true
                color: "#0d1418"
                horizontalAlignment: Text.AlignHCenter
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
                text: qsTr("zsh and Chromium are ready out of the box, and VS Code installs with the system — or later from the menu. Games install in one click from the menu — Steam and the usual launchers — and laptops usually get power management automatically.")
                font.pixelSize: 15
                font.family: "Inter"
                color: "#334155"
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
            }
        }
    }

    Slide {
        Column {
            anchors.centerIn: parent
            spacing: 18
            width: presentation.width * 0.8

            Rectangle {
                width: 244
                height: 244
                radius: 20
                color: "#0d1418"
                anchors.horizontalCenter: parent.horizontalCenter

                Image {
                    source: "logo.png"
                    width: 220
                    height: 220
                    fillMode: Image.PreserveAspectFit
                    anchors.centerIn: parent
                }
            }
            Text {
                text: qsTr("Sit back, it only takes a few minutes")
                font.pixelSize: 26
                font.family: "Inter"
                font.bold: true
                color: "#0d1418"
                horizontalAlignment: Text.AlignHCenter
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
                text: qsTr("Simorgh is copying the live system to your disk and setting up the bootloader. When it finishes, reboot, log in with SDDM, and the phoenix is yours.")
                font.pixelSize: 15
                font.family: "Inter"
                color: "#334155"
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
            }
        }
    }

    function onActivate() {
        presentation.currentSlide = 0;
    }

    function onLeave() {
    }

}
