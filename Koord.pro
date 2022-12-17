VERSION = 4.0.38

# use target name which does not use a capital letter at the beginning
contains(CONFIG, "noupcasename") {
    message(The target name is koord instead of Koord.)
    TARGET = koord
}

# allow detailed version info for intermediate builds (#475)
contains(VERSION, .*dev.*) {
    exists(".git/config") {
        GIT_DESCRIPTION=$$system(git describe --match=xxxxxxxxxxxxxxxxxxxx --always --abbrev --dirty) # the match should never match
        VERSION = "$$VERSION"-$$GIT_DESCRIPTION
        message("building version \"$$VERSION\" (intermediate in git repository)")
    } else {
        VERSION = "$$VERSION"-nogit
        message("building version \"$$VERSION\" (intermediate without git repository)")
    }
} else {
    message("building version \"$$VERSION\" (release)")
}

CONFIG += qt \
    thread \
    lrelease

QT += network \
    xml \
    concurrent \
    svg \
    widgets


INCLUDEPATH += src

# add support for full POSIX sockets over WebSockets
# https://emscripten.org/docs/porting/networking.html#full-posix-sockets-over-websocket-proxy-server
# LIBS += -lwebsocket.js -sPROXY_POSIX_SOCKETS -sUSE_PTHREADS -sPROXY_TO_PTHREAD

DEFINES += APP_VERSION=\\\"$$VERSION\\\" \
    CUSTOM_MODES \
    _REENTRANT

# some depreciated functions need to be kept for older versions to build
# TODO as soon as we drop support for the old Qt version, remove the following line
DEFINES += QT_NO_DEPRECATED_WARNINGS

wasm-emscripten {
    message(We have emscripten here.)
} else:win32 {
    DEFINES -= UNICODE # fixes issue with ASIO SDK (asiolist.cpp is not unicode compatible)
    DEFINES += NOMINMAX # solves a compiler error with std::min/max
    DEFINES += _WINSOCKAPI_ # try fix winsock / winsock2 redefinition problems
}


RCC_DIR = src/res
RESOURCES += src/resources.qrc

!contains(CONFIG, "serveronly") {
    FORMS_GUI += src/clientdlgbase.ui
}

HEADERS += src/buffer.h \
    src/channel.h \
    src/global.h \
    src/protocol.h \
    src/server.h \
    src/threadpool.h \
    src/socket.h \
    src/util.h \
    src/signalhandler.h \
    src/kdapplication.h \
    src/client.h \
    src/sound/soundbase.h \
    src/clientdlg.h


SOURCES += src/buffer.cpp \
    src/channel.cpp \
    src/kdapplication.cpp \
    src/main.cpp \
    src/protocol.cpp \
    src/server.cpp \
    src/signalhandler.cpp \
    src/socket.cpp \
    src/util.cpp \
    src/client.cpp \
    src/sound/soundbase.cpp \
    src/clientdlg.cpp


DISTFILES += README.md \
    distributions/koordrt.desktop.in \
    distributions/koordrt.png \
    distributions/koordrt.svg \
    src/res/CLEDBlack.png \
    src/res/CLEDBlackSmall.png \
    src/res/CLEDDisabledSmall.png \
    src/res/CLEDGreen.png \
    src/res/CLEDGreenSmall.png \
    src/res/CLEDGrey.png \
    src/res/CLEDGreySmall.png \
    src/res/CLEDRed.png \
    src/res/CLEDRedSmall.png \
    src/res/CLEDYellow.png \
    src/res/CLEDYellowSmall.png \
    src/res/LEDBlackSmall.png \
    src/res/LEDGreenSmall.png \
    src/res/LEDRedSmall.png \
    src/res/LEDYellowSmall.png \
    src/res/IndicatorGreen.png \
    src/res/IndicatorYellow.png \
    src/res/IndicatorRed.png \
    src/res/IndicatorYellowFancy.png \
    src/res/IndicatorRedFancy.png \
    src/res/faderbackground.png \
    src/res/faderhandle.png \
    src/res/faderhandlesmall.png \
    src/res/HLEDGreen.png \
    src/res/HLEDGreenSmall.png \
    src/res/HLEDBlack.png \
    src/res/HLEDBlackSmall.png \
    src/res/HLEDRed.png \
    src/res/HLEDRedSmall.png \
    src/res/HLEDYellow.png \
    src/res/HLEDYellowSmall.png \
    src/res/ledbuttonnotpressed.png \
    src/res/ledbuttonpressed.png \
    src/res/fronticon.png \
    src/res/fronticonserver.png \
    src/res/transparent1x1.png \
    src/res/mutediconorange.png \
    src/res/servertrayiconactive.png \
    src/res/servertrayiconinactive.png


contains(CONFIG, "headless") {
    DEFINES += HEADLESS
} else {
    HEADERS += $$HEADERS_GUI
    SOURCES += $$SOURCES_GUI
    FORMS += $$FORMS_GUI
}

#contains(CONFIG, "nojsonrpc") {
message(JSON-RPC support excluded from build.)
DEFINES += NO_JSON_RPC

# disable version check if requested (#370)
contains(CONFIG, "disable_version_check") {
    message(The version check is disabled.)
    DEFINES += DISABLE_VERSION_CHECK
}

# Enable formatting all code via `make clang_format`.
# Note: When extending the list of file extensions or when adding new code directories,
# be sure to update .github/workflows/coding-style-check.yml and .clang-format-ignore as well.
CLANG_FORMAT_SOURCES = $$files(*.cpp, true) $$files(*.mm, true) $$files(*.h, true)
CLANG_FORMAT_SOURCES = $$find(CLANG_FORMAT_SOURCES, ^\(android|ios|mac|linux|src|windows\)/)
CLANG_FORMAT_SOURCES ~= s!^\(libs/.*/|src/res/qrc_resources\.cpp\)\S*$!!g
clang_format.commands = 'clang-format -i $$CLANG_FORMAT_SOURCES'
QMAKE_EXTRA_TARGETS += clang_format
