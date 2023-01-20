#!/bin/bash
set -eu

# QT_VERSION=${QT_VER}
# export QT_VERSION

## Utility to build Qt for macOS 
# References:
# https://doc.qt.io/qt-6/macos-building.html
# https://doc.qt.io/qt-6/qsharedmemory.html#details


## WHY:
# We need it for SingleApplication - ie ensure one instance
# https://doc.qt.io/qt-6/qsharedmemory.html#details - see Mac section


## REQUIREMENTS (provided by Github macos build image):
# - cmake 

clone_qt() {
    ## Get Qt source -
    # 1) From archives
    # cd ${GITHUB_WORKSPACE}
    # MAJOR_VER=$(echo ${QT_VERSION} | cut -c -3) # get eg "6.4" when QT_VERSION=6.4.2
    # echo ">>> Downloading Qt source ..."
    # wget -q https://download.qt.io/archive/qt/${MAJOR_VER}/${QT_VERSION}/single/qt-everywhere-src-${QT_VERSION}.tar.xz
    # echo ">>> Unzipping qt-everywhere tar.xz file ..."
    # gunzip qt-everywhere-src-${QT_VERSION}.tar.xz        # uncompress the archive
    # echo ">>> Untarring qt-everywhere archive ..."
    # tar xf qt-everywhere-src-${QT_VERSION}.tar          # unpack it
    # cd qt-everywhere-src-${QT_VERSION}

    # 2) From Git
    cd $HOME
    # git clone git://code.qt.io/qt/qt5.git  # maybe add:  --depth 1 --shallow-submodules --no-single-branch
    git clone --depth 1 --branch ${QT_VERSION} git://code.qt.io/qt/qt5.git
}

build_qt() {

    cd $HOME/qt5
    git checkout ${QT_VERSION}
    perl init-repository --module-subset=qtbase,qtwebview,qtshadertools,qtdeclarative,qtsvg # get submodule source code

    ## PATCH webview
    patch -u qtwebview/src/plugins/darwin/qdarwinwebview.mm \
            -i ${GITHUB_WORKSPACE}/mac/qdarwinwebview.patch

    ## Configure Qt
    ## for universal build:
        # ./configure -- -DCMAKE_OSX_ARCHITECTURES="x86_64;arm64"
    # By default, Qt is configured for installation in the /usr/local/Qt-${QT_VERSION} directory,
    ./configure -nomake examples -nomake tests -- -DCMAKE_OSX_ARCHITECTURES="x86_64;arm64"

    # build:
    cmake --build . --parallel

    # install to /usr/local/Qt-${QT_VERSION}:
    cmake --install .

    # Create archive
    echo ">>> Archiving QT installation..."
    cd /usr/local/Qt-${QT_VERSION}
    tar cf ${GITHUB_WORKSPACE}/qt_mac_${QT_VERSION}_sysV.tar  .
    cd ${GITHUB_WORKSPACE}
    gzip qt_mac_${QT_VERSION}_sysV.tar

    # Output: ${GITHUB_WORKSPACE}/qt_mac_${QT_VERSION}_appstore.tar.gz

}

pass_artifacts_to_job() {
    mkdir -p ${GITHUB_WORKSPACE}/deploy
    
    mv -v ${GITHUB_WORKSPACE}/qt_mac_${QT_VERSION}_sysV.tar.gz ${GITHUB_WORKSPACE}/deploy/qt_mac_${QT_VERSION}_sysV.tar.gz

    echo ">>> Setting output as such: name=artifact_1::qt_mac_${QT_VERSION}_sysV.tar.gz"
    echo "artifact_1=qt_mac_${QT_VERSION}_sysV.tar.gz" >> "$GITHUB_OUTPUT"

}

case "${1:-}" in
    build)
        clone_qt
        build_qt
        ;;
    get-artifacts)
        pass_artifacts_to_job
        ;;
    localbuild)
        build_qt
        ;;
    *)
        echo "Unknown stage '${1:-}'"
        exit 1
esac