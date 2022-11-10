#!/bin/bash
set -eu -o pipefail

root_path=$(pwd)
client_target_name="Koord" # default
project_path="${root_path}/Koord.pro"
resources_path="${root_path}/src/res"
build_path="${root_path}/build"
deploy_path="${root_path}/deploy"
deploypkg_path="${root_path}/deploypkg"
macadhoc_cert_name=""
macapp_cert_name=""
macinst_cert_name=""

while getopts 'hs:a:i:' flag; do
    case "${flag}" in
        s)
            macadhoc_cert_name=$OPTARG
            if [[ -z "$macadhoc_cert_name" ]]; then
                echo "Please add the name of the adhoc certificate to use: -s \"<name>\""
            fi
            ;;
        a)
            macapp_cert_name=$OPTARG
            if [[ -z "$macapp_cert_name" ]]; then
                echo "Please add the name of the codesigning certificate to use: -a \"<name>\""
            fi
            ;;
        i)
            macinst_cert_name=$OPTARG
            if [[ -z "$macinst_cert_name" ]]; then
                echo "Please add the name of the installer signing certificate to use: -i \"<name>\""
            fi
            ;;
        h)
            echo "Usage: -s <adhoccertname> -a <codesigncertname> -i <instlrsigncertname> -p <macos_prov_profile>"
            exit 0
            ;;
        *)
            exit 1
            ;;
    esac
done

cleanup() {
    # Clean up previous deployments
    rm -rf "${build_path}"
    rm -rf "${deploy_path}"
    rm -rf "${deploypkg_path}"
    mkdir -p "${build_path}"
    mkdir -p "${deploy_path}"
    mkdir -p "${deploypkg_path}"
}

# build_app_compile()
# {
#     # local client_or_server="${1}"

#     # We need this in build environment otherwise defaults to webengine!!
#     # bug is here: https://code.qt.io/cgit/qt/qtwebview.git/tree/src/webview/qwebviewfactory.cpp?h=6.3.1#n51
#     # Note: not sure if this is useful here or only in Run env
#     export QT_WEBVIEW_PLUGIN="native"

#     # Build Koord
#     declare -a BUILD_ARGS=("_UNUSED_DUMMY=''")  # old bash fails otherwise
#     if [[ "${TARGET_ARCH:-}" ]]; then
#         BUILD_ARGS=("QMAKE_APPLE_DEVICE_ARCHS=${TARGET_ARCH}" "QT_ARCH=${TARGET_ARCH}")
#     fi
#     qmake "${project_path}" -o "${build_path}/Makefile" "CONFIG+=release" "${BUILD_ARGS[@]}" "${@:2}"
    
#     local job_count
#     job_count=$(sysctl -n hw.ncpu)

#     make -f "${build_path}/Makefile" -C "${build_path}" -j "${job_count}"
# }

build_app_compile_universal()
{
    local app_mode="${1}"
    # DEFINES+=APPSTORE - for switch in main.cpp
    # CONFIG+=appstore - for switch in qmake proj - entitlements file
    if [[ ${app_mode} == "appstore" ]]; then
        EXTRADEFINES="DEFINES+=APPSTORE"
        EXTRACONFIGS="CONFIG+=appstore"
    else
        EXTRADEFINES=
        EXTRACONFIGS=
    fi

    # We need this in build environment otherwise defaults to webengine!!?
    # bug is here: https://code.qt.io/cgit/qt/qtwebview.git/tree/src/webview/qwebviewfactory.cpp?h=6.3.1#n51
    # Note: not sure if this is useful here or only in Run env
    export QT_WEBVIEW_PLUGIN="native"

    local job_count
    job_count=$(sysctl -n hw.ncpu)

    # Build Koord for all requested architectures, defaulting to x86_64 if none provided:
    local target_name
    # target_name=${client_target_name} # ??
    local target_arch
    local target_archs_array
    IFS=' ' read -ra target_archs_array <<< "${TARGET_ARCHS:-x86_64}"
    for target_arch in "${target_archs_array[@]}"; do
        if [[ "${target_arch}" != "${target_archs_array[0]}" ]]; then
            # This is the second (or a later) first pass of a multi-architecture build.
            # We need to prune all leftovers from the previous pass here in order to force re-compilation now.
            make -f "${build_path}/Makefile" -C "${build_path}" distclean
        fi
        qmake "${project_path}" -o "${build_path}/Makefile" \
            "CONFIG+=release" ${EXTRACONFIGS} ${EXTRADEFINES} \
            "QMAKE_APPLE_DEVICE_ARCHS=${target_arch}" "QT_ARCH=${target_arch}" \
            "${@:2}"
        make -f "${build_path}/Makefile" -C "${build_path}" -j "${job_count}"
        target_name=$(sed -nE 's/^QMAKE_TARGET *= *(.*)$/\1/p' "${build_path}/Makefile")
        if [[ ${#target_archs_array[@]} -gt 1 ]]; then
            # When building for multiple architectures, move the binary to a safe place to avoid overwriting/cleaning by the other passes.
            mv "${build_path}/${target_name}.app/Contents/MacOS/${target_name}" "${deploy_path}/${target_name}.arch_${target_arch}"
        fi
    done
    if [[ ${#target_archs_array[@]} -gt 1 ]]; then
        echo "Building universal binary from: " "${deploy_path}/${target_name}.arch_"*
        lipo -create -output "${build_path}/${target_name}.app/Contents/MacOS/${target_name}" "${deploy_path}/${target_name}.arch_"*
        rm -f "${deploy_path}/${target_name}.arch_"*

        local file_output
        file_output=$(file "${build_path}/${target_name}.app/Contents/MacOS/${target_name}")
        echo "${file_output}"
        for target_arch in "${target_archs_array[@]}"; do
            if ! grep -q "for architecture ${target_arch}" <<< "${file_output}"; then
                echo "Missing ${target_arch} in file output -- build went wrong?"
                exit 1
            fi
        done
    fi
}

build_app_package() 
{
    # local target_name=$(sed -nE 's/^QMAKE_TARGET *= *(.*)$/\1/p' "${build_path}/Makefile")

    # copy in provisioning profile - BEFORE codesigning with macdeployqt
    echo ">>> Adding embedded.provisionprofile to ${build_path}/${client_target_name}.app/Contents/"
    cp ~/embedded.provisionprofile_adhoc ${build_path}/${client_target_name}.app/Contents/embedded.provisionprofile

    # Add Qt deployment dependencies
    # we do this here for signed / notarized dmg
    echo ">>> Doing macdeployqt for notarization ..."
    # Note: "-appstore-compliant" does NOT do any sandbox-enforcing or anything
    # it just skips certain plugins/modules - useful not to include all of WebEngine!
    macdeployqt "${build_path}/${client_target_name}.app" \
        -verbose=2 \
        -always-overwrite \
        -appstore-compliant \
        -sign-for-notarization="${macadhoc_cert_name}" \
        -qmldir="${root_path}/src"
    
    # debug:
    echo ">>> BUILD FINISHED. Listing of ${build_path}/${client_target_name}.app/ :"
    ls -al ${build_path}/${client_target_name}.app/

    # ## Copy in OpenSSL 1.x libs and add to Framework eg http://www.dafscollaborative.org/opencv-deploy.html
    # mkdir -p ${build_path}/${client_target_name}.app/Contents/Frameworks/
    # # Copy in SSL libs - from Homebrew installation 
    # cp /usr/local/opt/openssl@1.1/lib/libssl.1.1.dylib ${build_path}/${client_target_name}.app/Contents/Frameworks/
    # cp /usr/local/opt/openssl@1.1/lib/libcrypto.1.1.dylib ${build_path}/${client_target_name}.app/Contents/Frameworks/

    # # Update Framework registration stuff - to fix libcrypto/libssl errors - not working yet
    # # Firstly updating IDs:
    # install_name_tool -id @executable_path/../Frameworks/libssl.1.1.dylib \
    #     "${build_path}/${client_target_name}.app/Contents/Frameworks/libssl.1.1.dylib"
    # install_name_tool -id @executable_path/../Frameworks/libcrypto.1.1.dylib \
    #     "${build_path}/${client_target_name}.app/Contents/Frameworks/libcrypto.1.1.dylib"

    # # Changing libraries references:
    # install_name_tool -change lib/libssl.1.1.dylib @executable_path/../Frameworks/libssl.1.1.dylib \
    #     "${build_path}/${client_target_name}.app/Contents/MacOS/${client_target_name}"
    # install_name_tool -change lib/libcrypto.1.1.dylib @executable_path/../Frameworks/libcrypto.1.1.dylib \
    #     "${build_path}/${client_target_name}.app/Contents/MacOS/${client_target_name}"

    # # # Changing internal libraries cross-references: - necessary ????
    # # install_name_tool -change lib/libopencv_core.2.3.dylib @executable_path/../Frameworks/libopencv_core.2.3.dylib \
    # #     "${build_path}/${client_target_name}.app/Contents/Frameworks/libopencv_highgui.2.3.dylib"

    # copy app bundle to deploy dir to prep for dmg creation
    # leave original in place for pkg signing if necessary 
    # must use -R to preserve symbolic links
    cp -R ${build_path}/${client_target_name}.app ${deploy_path}
    echo ">>> COPY TO DEPLOY_DIR FINISHED. Listing of ${deploy_path}/${client_target_name}.app :"
    ls -al ${deploy_path}/${client_target_name}.app

    # # Cleanup
    # make -f "${build_path}/Makefile" -C "${build_path}" distclean
}

build_installer_pkg() 
{
    # local target_name=$(sed -nE 's/^QMAKE_TARGET *= *(.*)$/\1/p' "${build_path}/Makefile")
    local target_name=${client_target_name}

    ## Build installer pkg file - for submission to App Store
    echo ">>> build_installer_pkg: building with storesign certs...."

    # Clone the build directory to leave the adhoc signed app untouched
    cp -a ${build_path} "${build_path}_storesign"

    # copy in provisioning profile - BEFORE codesigning with macdeployqt
    echo ">>> Adding embedded.provisionprofile to ${build_path}_storesign/${target_name}.app/Contents/"
    cp ~/embedded.provisionprofile_store ${build_path}_storesign/${target_name}.app/Contents/embedded.provisionprofile

    # Add Qt deployment deps and codesign the app for App Store submission
    macdeployqt "${build_path}_storesign/${target_name}.app" \
        -verbose=2 \
        -always-overwrite \
        -hardened-runtime -timestamp -appstore-compliant \
        -sign-for-notarization="${macapp_cert_name}" \
        -qmldir="${root_path}/src/"

    # Create pkg installer and sign for App Store submission
    productbuild --sign "${macinst_cert_name}" --keychain build.keychain \
        --component "${build_path}_storesign/${target_name}.app" \
        /Applications \
        "${build_path}_storesign/Koord_${KOORD_BUILD_VERSION}.pkg"  

    # move created pkg file to prep for download
    mv "${build_path}_storesign/Koord_${KOORD_BUILD_VERSION}.pkg" "${deploypkg_path}"
}

build_disk_image()
{
    # local client_target_name="${1}"
    # local server_target_name="${2}"

    # Install create-dmg via brew. brew needs to be installed first.
    # Download and later install. This is done to make caching possible
    brew_install_pinned "create-dmg" "1.1.0"

    # try and test signature of bundle before build
    echo ">>> Testing signature of bundle ...." 
    codesign -vvv --deep --strict "${deploy_path}/Koord.app/"

    # Build installer image
    create-dmg \
      --volname "${client_target_name} Installer" \
      --background "${resources_path}/MacInstallerBanner.png" \
      --window-pos 200 400 \
      --window-size 935 390 \
      --app-drop-link 820 210 \
      --text-size 12 \
      --icon-size 72 \
      --icon "${client_target_name}.app" 630 210 \
      --eula "${root_path}/COPYING" \
      "${deploypkg_path}/${client_target_name}-${KOORD_BUILD_VERSION}-installer-mac.dmg" \
      "${deploy_path}/"
}

brew_install_pinned() {
    local pkg="$1"
    local version="$2"
    local pkg_version="${pkg}@${version}"
    local brew_bottle_dir="${HOME}/Library/Cache/koord-homebrew-bottles"
    local formula="/usr/local/Homebrew/Library/Taps/homebrew/homebrew-cask/Formula/${pkg_version}.rb"
    echo "Installing ${pkg_version}"
    mkdir -p "${brew_bottle_dir}"
    pushd "${brew_bottle_dir}"
    if ! find . | grep -qF "${pkg_version}--"; then
        echo "Building fresh ${pkg_version} package"
        brew developer on  # avoids a warning
        brew extract --version="${version}" "${pkg}" homebrew/cask
        brew install --build-bottle --formula "${formula}"
        brew bottle "${formula}"
        # In order to keep the result the same, we uninstall and re-install without --build-bottle later
        # (--build-bottle is documented to change behavior, e.g. by not running postinst scripts).
        brew uninstall "${pkg_version}"
    fi
    brew install "${pkg_version}--"*
    popd
}

# Check that we are running from the correct location
if [[ ! -f "${project_path}" ]]; then
    echo "Please run this script from the Qt project directory where $(basename "${project_path}") is located."
    echo "Usage: mac/$(basename "${0}")"
    exit 1
fi

# Cleanup previous deployments
cleanup

## optionally set client_target_name like this
# client_target_name=$(sed -nE 's/^QMAKE_TARGET *= *(.*)$/\1/p' "${build_path}/Makefile")

## Build app for DMG Installer
# compile code
build_app_compile_universal dmgdist
# build .app/ structure
build_app_package 
# create versioned DMG installer image  
build_disk_image

# Cleanup - make clean
echo ">>> DOING distclean ..."
make -f "${build_path}/Makefile" -C "${build_path}" distclean
# Clean deploy dir of app bundle dir - leave dmg build
echo ">>> DELETING ${deploy_path}/${client_target_name}.app/"
ls -al  "${deploy_path}/"
rm -fr "${deploy_path}/${client_target_name}.app"

##FIXME - only necessary due to SingleApplication / Posix problems 
## Now build for App Store:
# use a special preprocessor DEFINE for build-time flagging - avoid SingleApplication if for App Store!
#   DEFINES+=APPSTORE
# rebuild code again
build_app_compile_universal appstore
# rebuild .app/ structure
build_app_package 
# now build pkg for App store upload
build_installer_pkg

# make clean
make -f "${build_path}/Makefile" -C "${build_path}" distclean

