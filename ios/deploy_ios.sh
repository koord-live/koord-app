#!/bin/bash
set -eu -o pipefail

root_path="$(pwd)"
project_path="${root_path}/Koord.pro"
iosdeploy_path="${root_path}/ios"
resources_path="${root_path}/src/res"
build_path="${root_path}/build"
deploy_path="${root_path}/deploy"
iosdist_cert_name=""
keychain_pass=""

while getopts 'hs:k:' flag; do
    case "${flag}" in
        s)
            iosdist_cert_name=$OPTARG
            if [[ -z "$iosdist_cert_name" ]]; then
                echo "Please add the name of the certificate to use: -s \"<name>\""
            fi
            ;;
        k)
            keychain_pass=$OPTARG
            if [[ -z "$keychain_pass" ]]; then
                echo "Please add keychain password to use: -k \"<name>\""
            fi
            ;;
        h)
            echo "Usage: -s <cert name> for signing ios build"
            exit 0
            ;;
        *)
            exit 1
            ;;
    esac
done

cleanup()
{
    # Clean up previous deployments
    rm -rf "${build_path}"
    rm -rf "${deploy_path}"
    mkdir -p "${build_path}"
    mkdir -p "${build_path}/Exports"
    mkdir -p "${deploy_path}"
}

build_ipa()
{
    ## Builds an ipa file for iOS. Should be run from the repo-root

    # Create Xcode project file
    # rename project file for iOS to maintain consistency since rename
    qmake -spec macx-xcode Koord.pro

    # Note: presence of "SYMROOT" variable forces xcodebuild to use the legacy option instead of default
    # To force default Build Location (and thus avoid project clean errors with fastlane) we need to edit file
    echo "Removing these lines from Koord.xcodeproj/project.pbxproj ... "
    grep SYMROOT Koord.xcodeproj/project.pbxproj
    grep -v SYMROOT Koord.xcodeproj/project.pbxproj > Koord.xcodeproj/tmpproj
    mv Koord.xcodeproj/tmpproj Koord.xcodeproj/project.pbxproj
    echo "File Koord.xcodeproj/project.pbxproj edited."

    # disable deprecation warnings re legacy build system - XCode 13 errors on this
    # /usr/libexec/PlistBuddy -c "Add :DisableBuildSystemDeprecationDiagnostic bool" Koord.xcodeproj/project.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings
    # /usr/libexec/PlistBuddy -c "Set :DisableBuildSystemDeprecationDiagnostic true" Koord.xcodeproj/project.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings

    # Build
    if [[ -z "$iosdist_cert_name" ]]; then
        /usr/bin/xcodebuild -project Koord.xcodeproj  -list
        # Build unsigned
        /usr/bin/xcodebuild -project Koord.xcodeproj -scheme Koord -configuration Release clean archive \
            -archivePath "build/Koord.xcarchive" \
            CODE_SIGN_IDENTITY="" \
            CODE_SIGNING_REQUIRED=NO \
            CODE_SIGNING_ALLOWED=NO \
            CODE_SIGN_ENTITLEMENTS=""
    else
        ## NOTE: don't do anything here - leave this to later Github action
        echo "Not building anything here, deferring to later Github Action..."

        # /usr/bin/xcodebuild -project Koord.xcodeproj  -list
        # # Ref: https://developer.apple.com/forums/thread/70326
        # # // Builds the app into an archive
        # /usr/bin/xcodebuild -project Koord.xcodeproj -scheme Koord -configuration Release clean archive \
        #     -archivePath "build/Koord.xcarchive" \
        #     DEVELOPMENT_TEAM="TXZ4FR95HG" \
        #     CODE_SIGN_IDENTITY="" \
        #     CODE_SIGNING_REQUIRED=NO \
        #     CODE_SIGNING_ALLOWED=NO

        # # debug
        # echo "Archive contents after creating archive"
        # ls -alR build/Koord.xcarchive

        # #FIXME this may be redundant - since provisioning profile is specified in exportOptionsRelease.plist
        # cp ~/Library/MobileDevice/Provisioning\ Profiles/embedded.mobileprovision build/Koord.xcarchive/Products/Applications/Koord.app/

        # # // Exports the archive according to the export options specified by the plist
        # # export signed installer to build/Exports/Koord.ipa
        # /usr/bin/xcodebuild -exportArchive \
        #     -archivePath "build/Koord.xcarchive" \
        #     -exportPath  "build/Exports/" \
        #     -exportOptionsPlist "ios/exportOptionsRelease.plist" \
        #     DEVELOPMENT_TEAM="TXZ4FR95HG" \
        #     CODE_SIGN_IDENTITY="${iosdist_cert_name}" \
        #     CODE_SIGNING_REQUIRED=YES \
        #     CODE_SIGNING_ALLOWED=YES \
        #     CODE_SIGN_STYLE="Manual"

        # # debug
        # echo "Archive contents after creating signed installer"
        # ls -alR build/Koord.xcarchive
    fi

    # if no dist_cert, just create unsigned ipa file
    # otherwise skip that, and upload the signed ipa
    if [[ -z "$iosdist_cert_name" ]]; then
        # Generate unsigned ipa by copying the .app structure from the xcarchive directory
        cd ${root_path}
        mkdir -p build/unsigned/Payload
        cp -r build/Koord.xcarchive/Products/Applications/Koord.app build/unsigned/Payload/
        cd build/unsigned
        zip -0 -y -r Koord.ipa Payload/

        # move unsigned ipa file for upload
        cd ${root_path}
        mv build/unsigned/Koord.ipa deploy/Koord_unsigned.ipa
    else
        # NOTE: don't do anything here now
        echo "Not doing anything here, deferring to later Github Action..."

        # cd ${root_path}
        # # move signed ipa file for upload
        # mv build/Exports/Koord.ipa deploy/Koord_signed.ipa
    fi
}

# Cleanup previous deployments
cleanup

# Build ipa file for App Store submission (eg via Transporter etc)
build_ipa