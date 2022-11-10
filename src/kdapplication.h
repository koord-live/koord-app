#include <QApplication>
#include <QDebug>
#include <QFileOpenEvent>
//#include <clientdlg.h>
//#include <urlhandler.h>
//#include <singleapplication.h>

class KdApplication : public QApplication
{
    Q_OBJECT

public:
    KdApplication(int& argc, char* argv[]);

    int run();

public slots:
    void OnConnectFromURLHandler(const QString& value);

    // custom event handler for macOS (+ iOS?) custom url handling - koord://<address> urls
//    bool event(QEvent *event) override;
protected:
    bool event(QEvent *event) override;

};


