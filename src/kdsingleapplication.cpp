#include <QApplication>
#include <QDebug>
#include <QFileOpenEvent>
#include <clientdlg.h>
#include <urlhandler.h>
#include <kdapplication.h>
#include <kdsingleapplication.h>

// FIXME - DRY violation
// COPIES KdApplication :(

KdSingleApplication::KdSingleApplication (int& argc, char* argv[]) :
        SingleApplication(argc, argv, true)
{

}


// for iOS
void KdSingleApplication::OnConnectFromURLHandler(const QString& connect_url)
{
    // url format: "koord://<fqdn>:<port>"
    qInfo() << "OnConnectFromURLHandler connect_addr: " << connect_url;

    // here we have a URL open event on iOS
    // get reference to CClientDlg object, and call connect
    const QWidgetList &list = QApplication::topLevelWidgets();
    for(QWidget *w : list)
    {
        CClientDlg *mainWindow = qobject_cast<CClientDlg*>(w);
        if(mainWindow)
        {
//            qDebug() << "MainWindow found" << w;
            qInfo() << "Emitting EventJoinConnectClicked signal with url: " << connect_url;
            // send EventJoinConnectClicked signal, trigger OnEventJoinConnectClicked
            emit mainWindow->EventJoinConnectClicked(connect_url);
        }
    }

}


int KdSingleApplication::run()
{
    // for iOS
    auto url_handler = UrlHandler::getInstance();
    QObject::connect ( url_handler, &UrlHandler::connectUrlSet, this, &KdSingleApplication::OnConnectFromURLHandler );

    return KdSingleApplication::exec();
}


// for macOS - custom url handling
bool KdSingleApplication::event(QEvent *event)
{
    if (event->type() == QEvent::FileOpen)
    {
        QFileOpenEvent *openEvent = static_cast<QFileOpenEvent *>(event);
        qInfo() << "Open URL" << openEvent->url();
        QString nu_address = openEvent->url().toString();

        // here we have a URL open event on macOS
        // get reference to CClientDlg object, and call connect
        const QWidgetList &list = QApplication::topLevelWidgets();
        for(QWidget *w : list)
        {
            CClientDlg *mainWindow = qobject_cast<CClientDlg*>(w);
            if(mainWindow)
            {
                qDebug() << "MainWindow found" << w;
                qInfo() << "Emitting EventJoinConnectClicked signal with url: " << nu_address;
                // send EventJoinConnectClicked signal, trigger OnEventJoinConnectClicked
                emit mainWindow->EventJoinConnectClicked(nu_address);
            }
        }
    }

    return QApplication::event(event);
}



