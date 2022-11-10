#!/bin/bash
set -eu

QT_DIR=/usr/local/opt/qt
# The following version pinnings are semi-automatically checked for
# updates. Verify .github/workflows/bump-dependencies.yaml when changing those manually:
AQTINSTALL_VERSION=3.0.1

if [[ ! ${QT_VERSION:-} =~ [0-9]+\.[0-9]+\..* ]]; then
    echo "Environment variable QT_VERSION must be set to a valid Qt version"
    exit 1
fi
if [[ ! ${KOORD_BUILD_VERSION:-} =~ [0-9]+\.[0-9]+\.[0-9]+ ]]; then
    echo "Environment variable KOORD_BUILD_VERSION has to be set to a valid version string"
    exit 1
fi

setup() {
    if [[ -d "${QT_DIR}" ]]; then
        echo "Using Qt installation from previous run (actions/cache)"
    else
        echo "Installing Qt"
        python3 -m pip install "aqtinstall==${AQTINSTALL_VERSION}"
        # Install actual ios Qt:
        python3 -m aqt install-qt --outputdir "${QT_DIR}" mac ios "${QT_VERSION}" \
            --archives qtbase qtdeclarative qtsvg qttools \
            --modules qtwebview
        # Starting with Qt6, ios' qtbase install does no longer include a real qmake binary.
        # Instead, it is a script which invokes the mac desktop qmake.
        # As of aqtinstall 2.1.0 / 04/2022, desktop qtbase has to be installed manually:
        python3 -m aqt install-qt --outputdir "${QT_DIR}" mac desktop "${QT_VERSION}" \
            --archives qtbase qtdeclarative qtsvg qttools \
            --modules qtwebview
    fi
}


prepare_signing() {
    [[ "${SIGN_IF_POSSIBLE:-0}" == "1" ]] || return 1

    # Signing was requested, now check all prerequisites:
    [[ -n "${IOSDIST_CERTIFICATE:-}" ]] || return 1
    [[ -n "${IOSDIST_CERTIFICATE_ID:-}" ]] || return 1
    [[ -n "${IOSDIST_CERTIFICATE_PWD:-}" ]] || return 1
    [[ -n "${NOTARIZATION_USERNAME:-}" ]] || return 1
    [[ -n "${NOTARIZATION_PASSWORD:-}" ]] || return 1
    [[ -n "${IOS_PROV_PROFILE_B64:-}" ]] || return 1
    [[ -n "${KEYCHAIN_PASSWORD:-}" ]] || return 1

    echo "Signing was requested and all dependencies are satisfied"

    ## NOTE: These actions not needed since using new GH action
    # # use this as filename for Provisioning Profile
    # IOS_PP_PATH="embedded.mobileprovision"

    # ## Put the cert to a file
    # # IOSDIST_CERTIFICATE - iOS Distribution
    # echo "${IOSDIST_CERTIFICATE}" | base64 --decode > iosdist_certificate.p12

    # ## Echo Provisioning Profile to file
    # echo -n "${IOS_PROV_PROFILE_B64}" | base64 --decode > $IOS_PP_PATH

    # # Set up a keychain for the build:
    # security create-keychain -p "${KEYCHAIN_PASSWORD}" build.keychain
    # security default-keychain -s build.keychain
    # security unlock-keychain -p "${KEYCHAIN_PASSWORD}" build.keychain
    # security import iosdist_certificate.p12 -k build.keychain -P "${IOSDIST_CERTIFICATE_PWD}" -A -T /usr/bin/codesign
    # security set-key-partition-list -S apple-tool:,apple: -s -k "${KEYCHAIN_PASSWORD}" build.keychain
    # # add notarization/validation/upload password to keychain
    # xcrun altool --store-password-in-keychain-item --keychain build.keychain APPCONNAUTH -u $NOTARIZATION_USERNAME -p $NOTARIZATION_PASSWORD
    # # set lock timeout on keychain to 6 hours
    # security set-keychain-settings -lut 21600
    
    # # apply provisioning profile
    # #FIXME - maybe redundant?
    # mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
    # cp $IOS_PP_PATH ~/Library/MobileDevice/Provisioning\ Profiles

    # Tell Github Workflow that we need to validate and upload
    echo "ios_signed=true" >> "$GITHUB_OUTPUT"
    
    return 0
}

build_app_as_ipa() {
    # Add the Qt binaries to the PATH:
    export PATH="${QT_DIR}/${QT_VERSION}/ios/bin:${PATH}"

    # Mac's bash version considers BUILD_ARGS unset without at least one entry:
    BUILD_ARGS=("")
    if prepare_signing; then
        BUILD_ARGS=("-s" "${IOSDIST_CERTIFICATE_ID}" "-k" "${KEYCHAIN_PASSWORD}")
    fi
    ./ios/deploy_ios.sh "${BUILD_ARGS[@]}"
}

pass_artifact_to_job() {
    # just pass the one IPA file
    local SIGN_TEST=$(ls deploy/Koord_*.ipa | grep -i unsigned)
    if [ "${SIGN_TEST}" == "" ]; then
        echo "Signed, No artifact to pass..."
        # local artifact="Koord_${KOORD_BUILD_VERSION}_iOS_signed.ipa"
        # echo "Moving build artifact to deploy/${artifact}"
        # mkdir -p deploy
        # mv ./build/Koord.ipa ./deploy/Koord.ipa
        # echo "artifact_1=${artifact}" >> "$GITHUB_OUTPUT"
    else
        local artifact="Koord_${KOORD_BUILD_VERSION}_iOS_unsigned.ipa"
        echo "Moving build artifact to deploy/${artifact}"
        mv ./deploy/Koord_*.ipa "./deploy/${artifact}"
        echo "artifact_1=${artifact}" >> "$GITHUB_OUTPUT"
    fi

}

valid8_n_upload() {
    echo ">>> Processing validation and upload..."
    # attempt validate and then upload of ipa file, using previously-made keychain item
    xcrun altool --validate-app -f ${ARTIFACT_PATH} -t ios -u $NOTARIZATION_USERNAME -p $NOTARIZATION_PASSWORD
    xcrun altool --upload-app -f ${ARTIFACT_PATH} -t ios -u $NOTARIZATION_USERNAME -p $NOTARIZATION_PASSWORD
}

case "${1:-}" in
    setup)
        setup
        ;;
    build)
        build_app_as_ipa
        ;;
    get-artifacts)
        pass_artifact_to_job
        ;;
    validate_and_upload)
        valid8_n_upload
        ;;
    *)
        echo "Unknown stage '${1:-}'"
        exit 1
        ;;
esac
