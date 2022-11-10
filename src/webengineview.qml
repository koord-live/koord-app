import QtQuick 2.15
import QtWebView 1.1
import QtWebEngine 1.10
import QtQuick.Controls 2.15

Rectangle {

    id: orangerect
    color: "#303638"
    anchors.fill: parent

    BusyIndicator{
            anchors.centerIn: parent
            running: webView.loading === true
    }

    WebEngineView {
        id: webView
        anchors.fill: parent
        url: _clientdlg.video_url
        onFeaturePermissionRequested: {
            grantFeaturePermission(securityOrigin, feature, true);
        }
//        visible: _clientdlg.video_url !== ""
    }

}
