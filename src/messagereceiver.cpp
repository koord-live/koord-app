#include <QDebug>
#include <QApplication>
#include <clientdlg.h>
#include "messagereceiver.h"

MessageReceiver::MessageReceiver(QObject *parent) : QObject(parent)
{
}

// For use with SingleApplication ....
// Primary instance of app should receive this when secondary is opened
void MessageReceiver::receivedMessage(int instanceId, QByteArray message)
{
    qDebug() << "Received message from instance: " << instanceId;
//    qDebug() << "Message Text: " << message;

    // "message" should be args of how Secondary instance was invoked
    // eg invocation: "Koord.app koord://<host>:<port>"
    QString connect_url = QString(message);

    const QWidgetList &list = QApplication::topLevelWidgets();
    for(QWidget *w : list)
    {
        CClientDlg *mainWindow = qobject_cast<CClientDlg*>(w);
        if(mainWindow)
        {
            qInfo() << "Emitting EventJoinConnectClicked signal with url: " << connect_url;
            // send EventJoinConnectClicked signal, trigger OnEventJoinConnectClicked
            emit mainWindow->EventJoinConnectClicked(connect_url);
        }
    }
}
