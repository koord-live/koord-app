import QtQuick 2.15
import QtWebView 1.1
import QtQuick.Controls 2.15

Rectangle {

    id: orangerect
    color: "#303638"
    anchors.fill: parent

    Text {
        id: textghing
        anchors.fill: parent
        text: "NO SESSION"
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        font.family: "Helvetica"
        font.pointSize: 24
        color: "orange"
        visible: webview.url === "" ? true : false
    }

    BusyIndicator{
        id: busyindy
        anchors.centerIn: parent
        running: webView.loading === true
    }

    WebView {
        id: webView
        anchors.fill: parent
        url: _clientdlg.video_url
    }

}
