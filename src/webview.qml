import QtQuick 2.15
import QtWebView 1.1
import QtQuick.Controls 2.15


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
