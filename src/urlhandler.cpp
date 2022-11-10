// Custom url handling for iOS and Android
// Ref: https://doc.qt.io/qt-6/qdesktopservices.html#setUrlHandler

// Example taken from:
// https://forum.qt.io/topic/126730/how-to-automatically-launch-ios-app-with-parameters/3
// https://github.com/ucam-department-of-psychiatry/camcops/pull/185/files#diff-ef3481aa73554877e3b5e2b7e0e79dcfc63815b5db2783116d3f12df5ec1e726

#include <QDebug>
#include <QDesktopServices>
#include <QSysInfo>
#include <QUrl>
#include <QUrlQuery>
#include <clientdlg.h>
#include "urlhandler.h"

// Temp disable Android custom handling, since it's already working without custom parameter handling
//#ifdef Q_OS_ANDROID
//#include <jni.h>
//#endif

UrlHandler* UrlHandler::m_instance = NULL;

UrlHandler::UrlHandler()
{
    m_instance = this;

    QDesktopServices::setUrlHandler("koord", this, "handleUrl");
    qInfo() << "url_handler - setUrlHandler called";
}

void UrlHandler::handleUrl(const QUrl& url)
{
    qInfo() << Q_FUNC_INFO << url;

    // url will be: koord://<host>:<port>
    auto connect_url = url.toString();
    emit connectUrlSet(connect_url);

    qInfo() << "EMITTED connectUrlSet with url: " << connect_url;

//    auto query = QUrlQuery(url);
//    auto default_single_user_mode = query.queryItemValue("default_single_user_mode");
//    if (!default_single_user_mode.isEmpty()) {
//        emit defaultSingleUserModeSet(default_single_user_mode);
//    }

//    auto default_server_location = query.queryItemValue("default_server_location",
//                                                        QUrl::FullyDecoded);
//    if (!default_server_location.isEmpty()) {
//        emit defaultServerLocationSet(default_server_location);
//    }

//    auto default_access_key = query.queryItemValue("default_access_key");
//    if (!default_access_key.isEmpty()) {
//        emit defaultAccessKeySet(default_access_key);
//    }
}


UrlHandler* UrlHandler::getInstance()
{
    if (!m_instance)
        m_instance = new UrlHandler;
    qInfo() << "url_handler - getInstance called";
    return m_instance;
}

//  // Disable Android JNI / custom activity stuff for now
//#ifdef Q_OS_ANDROID
//// Called from .../android/src/live/koord/koord/KoordActivity.java
//#ifdef __cplusplus
//extern "C" {
//#endif

//JNIEXPORT void JNICALL
//  Java_io_koord_live_KoordActivity_handleAndroidUrl(
//      JNIEnv *env,
//      jobject obj,
//      jstring url)
//{
//    Q_UNUSED(obj)

//    const char *url_str = env->GetStringUTFChars(url, NULL);

//    UrlHandler::getInstance()->handleUrl(QUrl(url_str));

//    env->ReleaseStringUTFChars(url, url_str);
//}

//#ifdef __cplusplus
//}
//#endif

//#endif
