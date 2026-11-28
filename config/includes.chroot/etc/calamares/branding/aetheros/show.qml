import QtQuick 2.0
import calamares.slideshow 1.0

Presentation {
    id: presentation

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#11151d"

            Image {
                anchors.centerIn: parent
                source: "welcome.png"
                width: 180
                height: 180
                fillMode: Image.PreserveAspectFit
            }
        }
    }
}
