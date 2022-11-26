#!/bin/bash
set -eu

QT_BASEDIR="/opt/Qt"

# QT_VERSION=${QT_VER}
# export QT_VERSION

## Utility to build Qt for Android, on Linux (Ubuntu 2004 or 2204)
# References:
# - https://wiki.qt.io/Building_Qt_6_from_Git#Getting_the_source_code
# - https://doc.qt.io/qt-6/android-building.html
# - https://doc.qt.io/qt-6/android-getting-started.html

## WHY:
# Qt Android QtWebView does not have any way of allowing Camera/Mic permissions in a webpage, apparently
# Due to this bug: https://bugreports.qt.io/browse/QTBUG-63731
# So we need to hack and rebuild Android for Qt (at least some):
    # Hack in file: QtAndroidWebViewController.java
    # - Add following function to inner class QtAndroidWebChromeClient:
    #     @Override public void onPermissionRequest(PermissionRequest request) { request.grant(request.getResources()); }
    # - copy built jar QtAndroidWebView.jar to Qt installation to rebuild

## UPDATE Nov 2022: 
# We now build the whole of Qt for all ABIs as aqt is not installing armv7 and armv8a reliably any more 

## REQUIREMENTS (provided by Github ubuntu 2004 build image):
# - gradle 7.2+
# - android cli tools (sdkmanager)
# - cmake 

setup() {
    # Install build deps from apt
    sudo apt-get install -y --no-install-recommends \
        ninja-build \
        flex bison \
        libgl-dev \
        libegl-dev \
        libclang-11-dev \
        gperf \
        nodejs
    # openjdk-11-jdk \

    # Python deps for build
    sudo pip install html5lib
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
    export JAVA_HOME=${JAVA_HOME_11_X64}
    export PATH=$JAVA_HOME/bin:$PATH

    # Get Qt source - only base and modules necessary for QtWebView build
    # NOTE: "qt5" is legacy name of repo in qt.io, but the build is qt6 !
    cd $HOME
    # 1) From git...
    git clone git://code.qt.io/qt/qt5.git  # maybe add:  --depth 1 --shallow-submodules --no-single-branch
    cd qt5
    git checkout ${QT_VERSION}
    perl init-repository --module-subset=qtbase,qtwebview,qtshadertools,qtdeclarative # get submodule source code

    # Patch the QtAndroidWebViewController
    # note: patch made as per:
    #    diff -Naur QtAndroidWebViewController_orig.java QtAndroidWebViewController.java > webview_perms.patch
    patch -u qtwebview/src/jar/src/org/qtproject/qt/android/view/QtAndroidWebViewController.java -i \
        ${GITHUB_WORKSPACE}/android/qt_build_fix/webview_perms.patch

}

build_qt() {
    local ARCH_ABI="${1}"

    # Create shadow build directory
    mkdir -p $HOME/qt6-build-${ARCH_ABI}

    # Create install dir
    # mkdir -p $HOME/qt6-install
    mkdir -p /opt/Qt/${QT_VERSION}

    # Configure build for Android
    # ALSO configure and build for: armeabi-v7a
    cd $HOME/qt6-build-${ARCH_ABI}
    ../qt5/configure \
        -platform android-clang \
        -prefix /opt/Qt/${QT_VERSION}/${ARCH_ABI} \
        -android-ndk ${ANDROID_NDK_HOME} \
        -android-sdk ${ANDROID_SDK_ROOT} \
        -qt-host-path /opt/Qt/${QT_VERSION}/gcc_64 \
        -android-abis ${ARCH_ABI}

    # Build Qt for Android
    cmake --build . --parallel

    ## Optional install to prefix dir
    cmake --install .
    # qt build is now at $HOME/qt6-install/
        # - android_${ARCH_ABI}/jar/QtAndroidWebView.jar
}

pass_artifacts_to_job() {
    mkdir -p ${GITHUB_WORKSPACE}/deploy
    
    # mv -v $HOME/qt6_armeabi-v7a/jar/QtAndroidWebView.jar ${GITHUB_WORKSPACE}/deploy/QtAndroidWebView_armeabi-v7a.jar
    # mv -v $HOME/qt6_arm64-v8a/jar/QtAndroidWebView.jar ${GITHUB_WORKSPACE}/deploy/QtAndroidWebView_arm64-v8a.jar
    # mv -v $HOME/qt6_x86/jar/QtAndroidWebView.jar ${GITHUB_WORKSPACE}/deploy/QtAndroidWebView_x86.jar
    # mv -v $HOME/qt6_x86_64/jar/QtAndroidWebView.jar ${GITHUB_WORKSPACE}/deploy/QtAndroidWebView_x86_64.jar

    # echo ">>> Setting output as such: name=artifact_1::QtAndroidWebView_armeabi-v7a.jar"
    # echo "artifact_1=QtAndroidWebView_armeabi-v7a.jar" >> "$GITHUB_OUTPUT"
    # echo ">>> Setting output as such: name=artifact_2::QtAndroidWebView_arm64-v8a.jar"
    # echo "artifact_2=QtAndroidWebView_arm64-v8a.jar" >> "$GITHUB_OUTPUT"
    # echo ">>> Setting output as such: name=artifact_3::QtAndroidWebView_x86.jar"
    # echo "artifact_3=QtAndroidWebView_x86.jar" >> "$GITHUB_OUTPUT"
    # echo ">>> Setting output as such: name=artifact_4::QtAndroidWebView_x86_64.jar"
    # echo "artifact_4=QtAndroidWebView_x86_64.jar" >> "$GITHUB_OUTPUT"

    cd /opt/Qt/${QT_VERSION}
    # update armv7 dirname to expected path
    # mv android_armeabi-v7a android_armv7
    # mv android_arm64_v8a   android_arm64_v8a
    # mv android_x86 android_x86
    # mv android_x86_64 android_x86_64

    tar cf ${HOME}/qt_android_${QT_VERSION}.tar  .
    cd ${HOME}
    gzip qt_android_${QT_VERSION}.tar

    mv -v $HOME/qt_android_${QT_VERSION}.tar.gz ${GITHUB_WORKSPACE}/deploy/qt_android_${QT_VERSION}.tar.gz
    echo ">>> Setting output as such: name=artifact_1::qt_android_${QT_VERSION}.tar.gz"
    echo "artifact_1=qt_android_${QT_VERSION}.tar.gz" >> "$GITHUB_OUTPUT"
}

case "${1:-}" in
    build)
        setup
        build_qt "armeabi-v7a"
        build_qt "arm64-v8a"
        build_qt "x86"
        build_qt "x86_64"
        ;;
    get-artifacts)
        pass_artifacts_to_job
        ;;
    *)
        echo "Unknown stage '${1:-}'"
        exit 1
esac