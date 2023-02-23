import QtQuick
import QtWebView
import QtQuick.Controls


Rectangle {

    id: grayrect
    color: "#303638"
    anchors.fill: parent

    BusyIndicator{
            anchors.centerIn: parent
            running: webView.loading === true
    }

    WebView {
        id: webView
        anchors.fill: parent
        url: _clientdlg.video_url
    }

}
