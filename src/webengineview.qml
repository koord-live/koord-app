import QtQuick
import QtWebView
import QtWebEngine
import QtQuick.Controls

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
