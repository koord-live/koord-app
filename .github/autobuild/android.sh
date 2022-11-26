#!/bin/bash
set -eu

## From https://github.com/actions/runner-images/blob/main/images/linux/Ubuntu2204-Readme.md
# Tools already installed:
    # Android Command Line Tools 	7.0
    # Android SDK Build-tools  	33.0.0
    # Android SDK Platform-Tools 	33.0.3
    # Android SDK Platforms 	android-33 (rev 2)
    # Android SDK Tools 	26.1.1

# Env vars set: 
    # ANDROID_HOME 	/usr/local/lib/android/sdk
    # ANDROID_NDK 	/usr/local/lib/android/sdk/ndk/25.1.8937393
    # ANDROID_NDK_HOME 	/usr/local/lib/android/sdk/ndk/25.1.8937393
    # ANDROID_NDK_LATEST_HOME 	/usr/local/lib/android/sdk/ndk/25.1.8937393
    # ANDROID_NDK_ROOT 	/usr/local/lib/android/sdk/ndk/25.1.8937393
    # ANDROID_SDK_ROOT 	/usr/local/lib/android/sdk

ANDROID_PLATFORM=android-33
AQTINSTALL_VERSION=3.0.1
QT_VERSION=6.4.1
# QT_BASEDIR="/opt/Qt"
QT_BASEDIR="/home/runner/Qt"
BUILD_DIR=build
ANDROID_NDK_HOST="linux-x86_64"
# Only variables which are really needed by sub-commands are exported.
export JAVA_HOME=${JAVA_HOME_11_X64}
export PATH="${PATH}:${ANDROID_SDK_ROOT}/tools"
export PATH="${PATH}:${ANDROID_SDK_ROOT}/platform-tools"

if [[ ! ${KOORD_BUILD_VERSION:-} =~ [0-9]+\.[0-9]+\.[0-9]+ ]]; then
    echo "Environment variable KOORD_BUILD_VERSION has to be set to a valid version string"
    exit 1
fi

setup_ubuntu_dependencies() {
    export DEBIAN_FRONTEND="noninteractive"

    sudo apt-get -qq update
    sudo apt-get -qq --no-install-recommends -y install \
        build-essential zip unzip bzip2 p7zip-full curl chrpath openjdk-11-jdk-headless
}


setup_qt() {
    if [[ -d "${QT_BASEDIR}" ]]; then
        echo "Using Qt installation from previous run (actions/cache)"
    else
        echo "Installing Qt..."
        python3 -m pip install "aqtinstall==${AQTINSTALL_VERSION}"
        # icu needs explicit installation 
        # otherwise: "qmake: error while loading shared libraries: libicui18n.so.56: cannot open shared object file: No such file or directory"
        python3 -m aqt install-qt --outputdir "${QT_BASEDIR}" linux desktop "${QT_VERSION}" \
            --archives qtbase qtdeclarative qtsvg qttools icu

        # # Install Qt from Android build release
        wget -q https://github.com/koord-live/koord-app/releases/download/androidqt_${QT_VERSION}/qt_android_${QT_VERSION}.tar.gz \
            -O /tmp/qt_android_${QT_VERSION}.tar.gz
        tar xf /tmp/qt_android_${QT_VERSION}.tar.gz -C ${QT_BASEDIR}/${QT_VERSION}
        rm /tmp/qt_android_${QT_VERSION}.tar.gz
        # qt android now installed in QT_BASEDIR/

        # # Install Qt for target and patch in hacked Webview jars
        # python3 -m aqt install-qt --outputdir "${QT_BASEDIR}" linux android "${QT_VERSION}" android_x86 \
        #     --archives qtbase qtdeclarative qtsvg qttools \
        #     --modules qtwebview 
        # ##FIXME - HACK - SUBSTITUTE webview jar
        # wget https://github.com/koord-live/koord-app/releases/download/${QT_VERSION}/QtAndroidWebView_x86.jar -O \
        #     "${QT_BASEDIR}/${QT_VERSION}/android_x86/jar/QtAndroidWebView.jar"
        
        # python3 -m aqt install-qt --outputdir "${QT_BASEDIR}" linux android "${QT_VERSION}" android_x86_64 \
        #     --archives qtbase qtdeclarative qtsvg qttools \
        #     --modules qtwebview 
        # ##FIXME - HACK - SUBSTITUTE webview jar
        # wget https://github.com/koord-live/koord-app/releases/download/${QT_VERSION}/QtAndroidWebView_x86_64.jar -O \
        #     "${QT_BASEDIR}/${QT_VERSION}/android_x86_64/jar/QtAndroidWebView.jar"

        # # - 64bit required for Play Store
        # python3 -m aqt install-qt --outputdir "${QT_BASEDIR}" linux android "${QT_VERSION}" android_arm64_v8a \
        #     --archives qtbase qtdeclarative qtsvg qttools \
        #     --modules qtwebview 
        # ##FIXME - HACK - SUBSTITUTE webview jar
        # wget https://github.com/koord-live/koord-app/releases/download/${QT_VERSION}/QtAndroidWebView_arm64-v8a.jar -O \
        #     "${QT_BASEDIR}/${QT_VERSION}/android_arm64_v8a/jar/QtAndroidWebView.jar"

        # # Also install for arm_v7 to build for 32bit devices
        # python3 -m aqt install-qt --outputdir "${QT_BASEDIR}" linux android "${QT_VERSION}" android_armv7 \
        #     --archives qtbase qtdeclarative qtsvg qttools \
        #     --modules qtwebview 
        # ##FIXME - HACK - SUBSTITUTE webview jar
        # wget https://github.com/koord-live/koord-app/releases/download/${QT_VERSION}/QtAndroidWebView_armeabi-v7a.jar -O \
        #     "${QT_BASEDIR}/${QT_VERSION}/android_armv7/jar/QtAndroidWebView.jar"

    fi
}

install_android_openssl() {
    echo ">> Installing android_openssl as build dep ..."
    wget https://github.com/KDAB/android_openssl/archive/refs/tags/1.1.1l_1.0.2u.tar.gz 
    mkdir android_openssl 
    tar zxvf 1.1.1l_1.0.2u.tar.gz -C android_openssl --strip-components 1
    # android openssl libs are now installed at ./android_openssl/
}

build_app() {
    local ARCH_ABI="${1}"

    # local QT_DIR="${QT_BASEDIR}/${QT_VERSION}/android"
    local MAKE="${ANDROID_NDK_ROOT}/prebuilt/${ANDROID_NDK_HOST}/bin/make"

    echo "${GOOGLE_RELEASE_KEYSTORE}" | base64 --decode > android/android_release.keystore

    echo ">>> Compiling for ${ARCH_ABI} ..."

    # Override ANDROID_ABIS according to build target 
    # note: seems ANDROID_ABIS can be set here at cmdline, but ANDROID_VERSION_CODE cannot - must be in qmake file
    if [ "${ARCH_ABI}" == "android_armv7" ]; then
        echo ">>> Running qmake --version"
        ANDROID_ABIS=armeabi-v7a "${QT_BASEDIR}/${QT_VERSION}/${ARCH_ABI}/bin/qmake" --version
        echo ">>> Running qmake with ANDROID_ABIS=armeabi-v7a ..."
        ANDROID_ABIS=armeabi-v7a \
            "${QT_BASEDIR}/${QT_VERSION}/${ARCH_ABI}/bin/qmake" -spec android-clang
    elif [ "${ARCH_ABI}" == "android_arm64_v8a" ]; then
        echo ">>> Running qmake with ANDROID_ABIS=arm64-v8a ..."
        ANDROID_ABIS=arm64-v8a \
            "${QT_BASEDIR}/${QT_VERSION}/${ARCH_ABI}/bin/qmake" -spec android-clang
    elif [ "${ARCH_ABI}" == "android_x86" ]; then
        echo ">>> Running qmake with ANDROID_ABIS=arm64-v8a ..."
        ANDROID_ABIS=x86 \
            "${QT_BASEDIR}/${QT_VERSION}/${ARCH_ABI}/bin/qmake" -spec android-clang
    elif [ "${ARCH_ABI}" == "android_x86_64" ]; then
        echo ">>> Running qmake with ANDROID_ABIS=arm64-v8a ..."
        ANDROID_ABIS=x86_64 \
            "${QT_BASEDIR}/${QT_VERSION}/${ARCH_ABI}/bin/qmake" -spec android-clang
    fi
    "${MAKE}" -j "$(nproc)"
    "${MAKE}" INSTALL_ROOT="${BUILD_DIR}_${ARCH_ABI}" -f Makefile install
}

build_make_clean() {
    echo ">>> Doing make clean ..."
    local MAKE="${ANDROID_NDK_ROOT}/prebuilt/${ANDROID_NDK_HOST}/bin/make"
    "${MAKE}" clean
    rm -f Makefile
}

build_aab() {
    local ARCH_ABI="${1}"

    if [ "${ARCH_ABI}" == "android_armv7" ]; then
        TARGET_ABI=armeabi-v7a
    elif [ "${ARCH_ABI}" == "android_arm64_v8a" ]; then
        TARGET_ABI=arm64-v8a
    elif [ "${ARCH_ABI}" == "android_x86" ]; then
        TARGET_ABI=x86
    elif [ "${ARCH_ABI}" == "android_x86_64" ]; then
        TARGET_ABI=x86_64
    fi
    echo ">>> Building .aab file for ${TARGET_ABI}...."

    ANDROID_ABIS=${TARGET_ABI} ${QT_BASEDIR}/${QT_VERSION}/gcc_64/bin/androiddeployqt --input android-Koord-deployment-settings.json \
        --verbose \
        --output "${BUILD_DIR}_${ARCH_ABI}" \
        --aab \
        --release \
        --sign android/android_release.keystore koord \
            --storepass ${GOOGLE_KEYSTORE_PASS} \
        --android-platform "${ANDROID_PLATFORM}" \
        --jdk "${JAVA_HOME}" \
        --gradle
}

pass_artifact_to_job() {
    local ARCH_ABI="${1}"
    echo ">>> Deploying .aab file for ${ARCH_ABI}...."

    if [ "${ARCH_ABI}" == "android_armv7" ]; then
        NUM="1"
        BUILDNAME="arm"
    elif [ "${ARCH_ABI}" == "android_arm64_v8a" ]; then
        NUM="2"
        BUILDNAME="arm64"
    elif [ "${ARCH_ABI}" == "android_x86" ]; then
        NUM="3"
        BUILDNAME="x86"
    elif [ "${ARCH_ABI}" == "android_x86_64" ]; then
        NUM="4"
        BUILDNAME="x86_64"
    fi

    mkdir -p deploy
    local artifact="Koord_${KOORD_BUILD_VERSION}_android_${BUILDNAME}.aab"
    # debug to check for filenames
    ls -alR ${BUILD_DIR}_${ARCH_ABI}/build/outputs/bundle/release/
    ls -al ${BUILD_DIR}_${ARCH_ABI}/build/outputs/bundle/release/build_${ARCH_ABI}-release.aab
    echo ">>> Moving ${BUILD_DIR}_${ARCH_ABI}/build/outputs/bundle/release/build_${ARCH_ABI}-release.aab to deploy/${artifact}"
    mv "./${BUILD_DIR}_${ARCH_ABI}/build/outputs/bundle/release/build_${ARCH_ABI}-release.aab" "./deploy/${artifact}"
    echo ">>> Moved .aab file to deploy/${artifact}"
    echo ">>> Artifact number is: ${NUM}"
    echo ">>> Setting output as such: name=artifact_${NUM}::${artifact}"
    echo "artifact_${NUM}=${artifact}" >> "$GITHUB_OUTPUT"
}

case "${1:-}" in
    setup)
        setup_ubuntu_dependencies
        setup_qt
        install_android_openssl
        ;;
    build)
        # Build all targets in sequence
        build_app "android_armv7"
        build_aab "android_armv7"
        build_make_clean
        build_app "android_arm64_v8a"
        build_aab "android_arm64_v8a"
        build_make_clean
        build_app "android_x86"
        build_aab "android_x86"
        build_make_clean
        build_app "android_x86_64"
        build_aab "android_x86_64"
        ;;
    get-artifacts)
        pass_artifact_to_job "android_armv7"
        pass_artifact_to_job "android_arm64_v8a"
        pass_artifact_to_job "android_x86"
        pass_artifact_to_job "android_x86_64"
        ;;
    *)
        echo "Unknown stage '${1:-}'"
        exit 1
        ;;
esac
