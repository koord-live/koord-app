import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {

    id: orangerect
    color: "#303638"
    anchors.fill: parent

    Text {
            anchors.fill: parent
            text: "NO SESSION"
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            font.family: "Helvetica"
            font.pointSize: 24
            color: "orange"
    }

}
