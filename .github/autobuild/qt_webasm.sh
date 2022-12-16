#!/bin/bash
set -eu

QT_BASEDIR="/opt/Qt"

## REQUIREMENTS (provided by Github ubuntu 2004 build image):
# - cmake 

## Utility to build Qt for Android, on Linux (Ubuntu 2004 or 2204)
# References:
# - https://doc.qt.io/qt-6/wasm.html#developing-with-qt-for-webassembly

## WHY:
# Need custom webassembly qt for:
# - multi-threading for QtConcurrent


setup() {
    # Install build deps from apt
    sudo apt-get install -y --no-install-recommends \
        ninja-build \
        flex bison \
        libgl-dev \
        libegl-dev
    #     libclang-11-dev \
    #     gperf \
    #     nodejs
    # openjdk-11-jdk \

    # Install emscripten
    cd $HOME
    git clone https://github.com/emscripten-core/emsdk.git
    cd emsdk
    ./emsdk install 3.1.14
    ./emsdk activate 3.1.14
    source ./emsdk_env.sh

    # Python deps for build
    # sudo pip install html5lib
    sudo pip install aqtinstall

    # Install Qt 
    mkdir $HOME/Qt
    cd $HOME/Qt
    aqt install-qt --outputdir "${QT_BASEDIR}" linux desktop ${QT_VERSION} \
        --archives qtbase qtdeclarative qtsvg qttools icu \
        --modules qtshadertools

    # Set path env vars for build
    # export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
    # use Github-installed JDK
    # export JAVA_HOME=${JAVA_HOME_11_X64}
    # export PATH=$JAVA_HOME/bin:$PATH

    # Get Qt source - only base and modules necessary for QtWebView build
    # NOTE: "qt5" is legacy name of repo in qt.io, but the build is qt6 !
    cd $HOME
    # 1) From git...
    git clone git://code.qt.io/qt/qt5.git  # maybe add:  --depth 1 --shallow-submodules --no-single-branch
    cd qt5
    git checkout ${QT_VERSION}
    # get submodule source code
    perl init-repository --module-subset=qtbase,qtshadertools,qtdeclarative,qtsvg 

}

build_qt() {
    
    cd $HOME/qt5

    ./configure -feature-thread -qt-host-path "${QT_BASEDIR}/6.4.1/gcc_64" -skip qtdoc -skip qttranslations -platform wasm-emscripten -prefix $PWD/qtbase

    cmake --build . --parallel -t qtbase -t qtdeclarative -t qtsvg

    # Build Qt for Android
    # cmake --build . --parallel

    ## Install to prefix dir
    cmake --install .

}

pass_artifacts_to_job() {
    mkdir -p ${GITHUB_WORKSPACE}/deploy
    
    cd /opt/Qt/${QT_VERSION}
    tar cf ${HOME}/qt_webasm_${QT_VERSION}.tar  .
    cd ${HOME}
    gzip qt_webasm_${QT_VERSION}.tar

    mv -v $HOME/qt_webasm_${QT_VERSION}.tar.gz ${GITHUB_WORKSPACE}/deploy/qt_webasm_${QT_VERSION}.tar.gz
    echo ">>> Setting output as such: name=artifact_1::qt_webasm_${QT_VERSION}.tar.gz"
    echo "artifact_1=qt_webasm_${QT_VERSION}.tar.gz" >> "$GITHUB_OUTPUT"
}

case "${1:-}" in
    build)
        setup
        build_qt 
        ;;
    get-artifacts)
        pass_artifacts_to_job
        ;;
    *)
        echo "Unknown stage '${1:-}'"
        exit 1
esac