// For iOS (and Android) custom url handling

#pragma once
#include <QObject>
#include <QUrl>

class QUrl;

class UrlHandler : public QObject
{
    Q_OBJECT

public:
    explicit UrlHandler();
    static UrlHandler* getInstance();

signals:
    void connectUrlSet(const QString& connect_url);
//    void defaultSingleUserModeSet(const QString& single_user_mode);
//    void defaultServerLocationSet(const QString& server_location);
//    void defaultAccessKeySet(const QString& access_key);

public slots:
    void handleUrl(const QUrl& url);

private:
    static UrlHandler* m_instance;
};
