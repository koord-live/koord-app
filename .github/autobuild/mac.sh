#!/bin/bash
set -eu

QT_DIR=/usr/local/opt/qt
QT_POSIX_DIR=/usr/local/opt/qt_posix
# QT_POSIX_VER=6.4.2

# The following version pinnings are semi-automatically checked for
# updates. Verify .github/workflows/bump-dependencies.yaml when changing those manually:
AQTINSTALL_VERSION=3.0.2

TARGET_ARCHS="${TARGET_ARCHS:-}"

if [[ ! ${QT_VERSION:-} =~ [0-9]+\.[0-9]+\..* ]]; then
    echo "Environment variable QT_VERSION must be set to a valid Qt version"
    exit 1
fi
if [[ ! ${KOORD_BUILD_VERSION:-} =~ [0-9]+\.[0-9]+\.[0-9]+ ]]; then
    echo "Environment variable KOORD_BUILD_VERSION has to be set to a valid version string"
    exit 1
fi

setup() {
    if [[ -d "${QT_POSIX_DIR}" ]]; then
        echo "Using Qt installation from previous run (actions/cache)"
    else
        ###############################
        ## Setup Qt
        ###############################
        echo "Installing Qt..."
        # ## NORMAL QT - which we like
        python3 -m pip install "aqtinstall==${AQTINSTALL_VERSION}"
        # no need for webengine in Mac! At all! Like iOS
        # except for Legacy version :/
        WEBENGINE_MODS = ""
        if [ "${TARGET_ARCHS}" == "x86_64" ]; then
            WEBENGINE_MODS = "qtwebengine qtwebchannel qtpositioning"
        fi
        python3 -m aqt install-qt --outputdir "${QT_DIR}" mac desktop "${QT_VERSION}" \
            --archives qtbase qtdeclarative qtsvg qttools \
            --modules qtwebview ${WEBENGINE_MODS}
            
        ## POSIX QT - for AppStore and SingleApplication compatibility
        # Install Qt from POSIX build release
        echo "Installing AppStore Qt ..."
        wget -q https://github.com/koord-live/koord-app/releases/download/macqt_${QT_VERSION}/qt_mac_${QT_VERSION}_appstore.tar.gz \
            -O /tmp/qt_mac_${QT_VERSION}_posix.tar.gz
        echo "Creating QT_POSIX_DIR : ${QT_POSIX_DIR} ... "
        mkdir ${QT_POSIX_DIR}
        tar xf /tmp/qt_mac_${QT_VERSION}_posix.tar.gz -C ${QT_POSIX_DIR}
        rm /tmp/qt_mac_${QT_VERSION}_posix.tar.gz
        # qt now installed in QT_POSIX_DIR

        # echo "Patching SingleApplication for POSIX/AppStore compliance ..."
        # # note: patch made as per:
        # #    diff -Naur singleapplication_p_orig.cpp singleapplication_p.cpp > macOS_posix.patch
        # patch -u ${GITHUB_WORKSPACE}/singleapplication/singleapplication_p.cpp \
        #     -i ${GITHUB_WORKSPACE}/mac/macOS_posix.patch

        ###################################
        ## Install other deps eg OpenSSL
        ###################################
        # brew install openssl@1.1 # 1.1 already installed !
    fi
}

prepare_signing() {
    ##  Certificate types in use:
    # - MAC_ADHOC_CERT - Developer ID Application - for codesigning for adhoc release
    # - MACAPP_CERT - Mac App Distribution - codesigning for App Store submission
    # - MACAPP_INST_CERT - Mac Installer Distribution - for signing installer pkg file for App Store submission

    [[ "${SIGN_IF_POSSIBLE:-0}" == "1" ]] || return 1

    # Signing was requested, now check all prerequisites:
    [[ -n "${MAC_ADHOC_CERT:-}" ]] || return 1
    [[ -n "${MAC_ADHOC_CERT_ID:-}" ]] || return 1
    [[ -n "${MAC_ADHOC_CERT_PWD:-}" ]] || return 1
    [[ -n "${MACAPP_CERT:-}" ]] || return 1
    [[ -n "${MACAPP_CERT_ID:-}" ]] || return 1
    [[ -n "${MACAPP_CERT_PWD:-}" ]] || return 1
    [[ -n "${MACAPP_INST_CERT:-}" ]] || return 1
    [[ -n "${MACAPP_INST_CERT_ID:-}" ]] || return 1
    [[ -n "${MACAPP_INST_CERT_PWD:-}" ]] || return 1
    [[ -n "${MAC_PROV_PROF_STORE:-}" ]] || return 1
    [[ -n "${MAC_PROV_PROF_ADHOC:-}" ]] || return 1
    [[ -n "${NOTARIZATION_USERNAME:-}" ]] || return 1
    [[ -n "${NOTARIZATION_PASSWORD:-}" ]] || return 1
    [[ -n "${KEYCHAIN_PASSWORD:-}" ]] || return 1

    echo "Signing was requested and all dependencies are satisfied"

    ## Put the certs to files
    echo "${MAC_ADHOC_CERT}" | base64 --decode > macadhoc_certificate.p12
    echo "${MACAPP_CERT}" | base64 --decode > macapp_certificate.p12
    echo "${MACAPP_INST_CERT}" | base64 --decode > macinst_certificate.p12
    
    # ## Echo Provisioning Profiles to files - store AND adhoc
    # store pp corresponds to macapp_cert for store distribution
    echo -n "${MAC_PROV_PROF_STORE}" | base64 --decode > ~/embedded.provisionprofile_store
    # adhoc pp corresponds to mac_adhoc_cert for dmg installer adhoc distribution
    echo -n "${MAC_PROV_PROF_ADHOC}" | base64 --decode > ~/embedded.provisionprofile_adhoc

    # Set up a keychain for the build:
    security create-keychain -p "${KEYCHAIN_PASSWORD}" build.keychain
    security default-keychain -s build.keychain
    # Remove default re-lock timeout to avoid codesign hangs:
    security set-keychain-settings build.keychain
    security unlock-keychain -p "${KEYCHAIN_PASSWORD}" build.keychain
    # add certs to keychain
    security import macadhoc_certificate.p12 -k build.keychain -P "${MAC_ADHOC_CERT_PWD}" -A -T /usr/bin/codesign 
    security import macapp_certificate.p12 -k build.keychain -P "${MACAPP_CERT_PWD}" -A -T /usr/bin/codesign
    security import macinst_certificate.p12 -k build.keychain -P "${MACAPP_INST_CERT_PWD}" -A -T /usr/bin/productbuild 

    # allow the default keychain access to cli utilities
    security set-key-partition-list -S apple-tool:,apple: -s -k "${KEYCHAIN_PASSWORD}" build.keychain

    # Tell Github Workflow that we need notarization & stapling:
    echo "macos_signed=true" >> "$GITHUB_OUTPUT"
    return 0
}

build_app_and_packages() {
    # Add the qt binaries to the PATH.
    ## For normal Qt:
    NORMAL_PATH="${QT_DIR}/${QT_VERSION}/macos/bin:${PATH}"
    POSIX_PATH="${QT_POSIX_DIR}/bin:${PATH}"
    ## For POSIX Qt:
    # export PATH="${QT_POSIX_DIR}/bin:${PATH}"

    # Mac's bash version considers BUILD_ARGS unset without at least one entry:
    BUILD_ARGS=("")
    if prepare_signing; then
        BUILD_ARGS=("-s" "${MAC_ADHOC_CERT_ID}" "-a" "${MACAPP_CERT_ID}" \
            "-i" "${MACAPP_INST_CERT_ID}")
    fi
    
    # Build for normal mode
    export PATH=${NORMAL_PATH}
    # export PATH=${POSIX_PATH}
    echo "Path set to ${PATH}, building ..."
    TARGET_ARCHS="${TARGET_ARCHS}" ./mac/deploy_mac.sh "${BUILD_ARGS[@]}"

    # # Now build for posix mode - just for appstore
    if [ "${TARGET_ARCHS}" == "x86_64 arm64" ]; then
        export PATH=${POSIX_PATH}
        echo "Path set to ${PATH}, building for appstore ...."
        TARGET_ARCHS="${TARGET_ARCHS}" ./mac/deploy_mac.sh "${BUILD_ARGS[@]}" -m appstore
    fi
    
}

pass_artifact_to_job() {
    # hack: if we are building x86_64 only, assume it is the legacy build
    if [ "${TARGET_ARCHS}" == "x86_64" ]; then
        artifact="Koord_${KOORD_BUILD_VERSION}_legacy.dmg"    
    else
        artifact="Koord_${KOORD_BUILD_VERSION}.dmg"
    fi
    echo "Moving build artifact to deploy/${artifact}"
    mv -v ./deploypkg/Koord-${KOORD_BUILD_VERSION}-installer-mac.dmg "./deploy/${artifact}"
    echo "artifact_1=${artifact}" >> "$GITHUB_OUTPUT"

    artifact2="Koord_${KOORD_BUILD_VERSION}_mac_storesign.pkg"
    if [ -f ./deploypkg/Koord*.pkg ]; then
        echo "Moving build artifact2 to deploy/${artifact2}"
        mv -v ./deploypkg/Koord*.pkg "./deploy/${artifact2}"
        echo "artifact_2=${artifact2}" >> "$GITHUB_OUTPUT"
    fi
}

valid8_n_upload() {
    echo ">>> Processing validation and upload..."
    
    # test the signature of package
    pkgutil --check-signature "${ARTIFACT_PATH}"
    
    # validate and upload
    xcrun altool --validate-app -f "${ARTIFACT_PATH}" -t macos -u $NOTARIZATION_USERNAME -p $NOTARIZATION_PASSWORD
    xcrun altool --upload-app -f "${ARTIFACT_PATH}" -t macos -u $NOTARIZATION_USERNAME -p $NOTARIZATION_PASSWORD

    # notarytool results in "Invalid" status
    ## Use notarytool to submit to AppStore Connect:
    # xcrun notarytool submit "${ARTIFACT_PATH}" \
    #     --apple-id $NOTARIZATION_USERNAME \
    #     --team-id $APPLE_TEAM_ID \
    #     --password $NOTARIZATION_PASSWORD \
    #     --wait

}

case "${1:-}" in
    setup)
        setup
        ;;
    build)
        build_app_and_packages
        ;;
    get-artifacts)
        pass_artifact_to_job
        ;;
    validate_and_upload)
        if [ "${TARGET_ARCHS}" == "x86_64 arm64" ]; then
            valid8_n_upload
        else
            echo "Legacy build, not uploading to store ..."
        fi
        ;;
    *)
        echo "Unknown stage '${1:-}'"
        exit 1
        ;;
esac
