import QtQuick 2.9
import QtWebView 1.1
import QtWebEngine 1.5
import QtQuick.Controls 2.2

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
        profile: webengprofile

    }

    WebEngineProfile {
        id: webengprofile
        // this is latest Safari user-agent
        // TODO: experiment with other (less demanding?) user agents ...
        httpUserAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 13_2_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.3 Safari/605.1.15"
    }

}
