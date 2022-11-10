#include <QApplication>
#include <QDebug>
#include <QFileOpenEvent>
#include <singleapplication.h>

// FIXME - DRY violation
// COPIES KdApplication :(

class KdSingleApplication : public SingleApplication
{
    Q_OBJECT

public:
    KdSingleApplication(int& argc, char* argv[]);

    int run();

public slots:
    void OnConnectFromURLHandler(const QString& value);

    // custom event handler for macOS (+ iOS?) custom url handling - koord://<address> urls
//    bool event(QEvent *event) override;
protected:
    bool event(QEvent *event) override;

};


