#!/bin/bash
set -eu

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

## REQUIREMENTS (provided by Github ubuntu 2004 build image):
# - gradle 7.2+
# - android cli tools (sdkmanager)
# - cmake 

setup() {
    # Install build deps from apt
    sudo apt-get install -y --no-install-recommends \
        openjdk-11-jdk \
        ninja-build \
        flex bison \
        libgl-dev \
        libegl-dev \
        libclang-11-dev \
        gperf \
        nodejs

    # Python deps for build
    sudo pip install html5lib
    sudo pip install aqtinstall

    # Install Qt 
    mkdir $HOME/Qt
    cd $HOME/Qt
    aqt install-qt linux desktop ${QT_VERSION} -m qtshadertools

    # Set path env vars for build
    export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
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

build_jar() {
    local ARCH_ABI="${1}"

    # Create shadow build directory
    mkdir -p $HOME/qt6-build-${ARCH_ABI}

    # Configure build for Android
    # ALSO configure and build for: armeabi-v7a
    cd $HOME/qt6-build-${ARCH_ABI}
    ../qt5/configure \
        -platform android-clang \
        -prefix $HOME/qt6_${ARCH_ABI} \
        -android-ndk ${ANDROID_NDK_HOME} \
        -android-sdk ${ANDROID_SDK_ROOT} \
        -qt-host-path $HOME/Qt/${QT_VERSION}/gcc_64 \
        -android-abis ${ARCH_ABI}

    # Build Qt for Android
    cmake --build . --parallel

    # Archive resultant jar here:
    ls -al ./qtbase/jar/QtAndroidWebView.jar # <-- file to substitute

    ## Optional install to prefix dir
    cmake --install .
    # file is now at $HOME/qt6_${ARCH_ABI}/jar/QtAndroidWebView.jar
}

pass_artifacts_to_job() {
    mkdir -p ${GITHUB_WORKSPACE}/deploy
    
    mv -v $HOME/qt6_armeabi-v7a/jar/QtAndroidWebView.jar ${GITHUB_WORKSPACE}/deploy/QtAndroidWebView_armeabi-v7a.jar
    mv -v $HOME/qt6_arm64-v8a/jar/QtAndroidWebView.jar ${GITHUB_WORKSPACE}/deploy/QtAndroidWebView_arm64-v8a.jar
    mv -v $HOME/qt6_x86/jar/QtAndroidWebView.jar ${GITHUB_WORKSPACE}/deploy/QtAndroidWebView_x86.jar
    mv -v $HOME/qt6_x86_64/jar/QtAndroidWebView.jar ${GITHUB_WORKSPACE}/deploy/QtAndroidWebView_x86_64.jar

    echo ">>> Setting output as such: name=artifact_1::QtAndroidWebView_armeabi-v7a.jar"
    echo "artifact_1=QtAndroidWebView_armeabi-v7a.jar" >> "$GITHUB_OUTPUT"
    echo ">>> Setting output as such: name=artifact_2::QtAndroidWebView_arm64-v8a.jar"
    echo "artifact_2=QtAndroidWebView_arm64-v8a.jar" >> "$GITHUB_OUTPUT"
    echo ">>> Setting output as such: name=artifact_3::QtAndroidWebView_x86.jar"
    echo "artifact_3=QtAndroidWebView_x86.jar" >> "$GITHUB_OUTPUT"
    echo ">>> Setting output as such: name=artifact_4::QtAndroidWebView_x86_64.jar"
    echo "artifact_4=QtAndroidWebView_x86_64.jar" >> "$GITHUB_OUTPUT"
}

case "${1:-}" in
    build)
        setup
        build_jar "armeabi-v7a"
        build_jar "arm64-v8a"
        build_jar "x86"
        build_jar "x86_64"
        ;;
    get-artifacts)
        pass_artifacts_to_job
        ;;
    *)
        echo "Unknown stage '${1:-}'"
        exit 1
esac