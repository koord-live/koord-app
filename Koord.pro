VERSION = 4.0.29

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
    svg

contains(CONFIG, "headless") {
    message(Headless mode activated.)
    QT -= gui
} else {
    QT += widgets \
        quickwidgets \
        webview
}

# add SingleApplication support
include(singleapplication/singleapplication.pri)
DEFINES += QAPPLICATION_CLASS=QApplication

INCLUDEPATH += src

INCLUDEPATH_OPUS = libs/opus/include \
    libs/opus/celt \
    libs/opus/silk \
    libs/opus/silk/float \
    libs/opus/silk/fixed \
    libs/opus

DEFINES += APP_VERSION=\\\"$$VERSION\\\" \
    CUSTOM_MODES \
    _REENTRANT

# some depreciated functions need to be kept for older versions to build
# TODO as soon as we drop support for the old Qt version, remove the following line
DEFINES += QT_NO_DEPRECATED_WARNINGS

win32 {
    # Windows desktop does not have native web runtime, need to package
    QT += quick \
        webenginecore

    DEFINES -= UNICODE # fixes issue with ASIO SDK (asiolist.cpp is not unicode compatible)
    DEFINES += NOMINMAX # solves a compiler error in qdatetime.h (Qt5)
    DEFINES += _WINSOCKAPI_ # try fix winsock / winsock2 redefinition problems
    RC_FILE = src/res/win-mainicon.rc

    LIBS += ole32.lib \
        user32.lib \
        advapi32.lib \
        winmm.lib \
        ws2_32.lib
    # also add KoordASIO lib, 64bit only
    # Full path in build will be:
    # D:\a\koord-rt\koord-rt\KoordASIO\src\out\build\x64-Release\FlexASIO-prefix\src\FlexASIO-build\FlexASIO
    LIBS += -L$$PWD/KoordASIO/src/out/build/x64-Release/FlexASIO-prefix/src/FlexASIO-build/FlexASIO -lKoordASIO
    INCLUDEPATH += $$PWD/KoordASIO/src/out/build/x64-Release/FlexASIO-prefix/src/FlexASIO-build/FlexASIO
    DEPENDPATH += $$PWD/KoordASIO/src/out/build/x64-Release/FlexASIO-prefix/src/FlexASIO-build/FlexASIO

    LIBS += -L$$PWD/KoordASIO/src/out/build/x64-Release/install/bin/ -lportaudio
    LIBS += -L$$PWD/KoordASIO/src/out/build/x64-Release/install/lib/ -lportaudio
    INCLUDEPATH += $$PWD/KoordASIO/src/out/build/x64-Release/install/bin/
    DEPENDPATH += $$PWD/KoordASIO/src/out/build/x64-Release/install/bin/

    # Qt5 had a special qtmain library which took care of forwarding the MSVC default WinMain() entrypoint to
    # the platform-agnostic main().
    # Qt6 is still supposed to have that lib under the new name QtEntryPoint. As it does not seem
    # to be effective when building with qmake, we are rather instructing MSVC to use the platform-agnostic
    # main() entrypoint directly:
    QMAKE_LFLAGS += /subsystem:windows /ENTRY:mainCRTStartup

    !exists(windows/ASIOSDK2) {
        error("Error: ASIOSDK2 must be placed in reporoot windows/ folder.")

    }

    # Important: Keep those ASIO includes local to this build target in
    # order to avoid poisoning other builds license-wise.
    HEADERS += src/sound/asio/sound.h
    SOURCES += src/sound/asio/sound.cpp \
        windows/ASIOSDK2/common/asio.cpp \
        windows/ASIOSDK2/host/asiodrivers.cpp \
        windows/ASIOSDK2/host/pc/asiolist.cpp
    INCLUDEPATH += windows/ASIOSDK2/common \
        windows/ASIOSDK2/host \
        windows/ASIOSDK2/host/pc

} else:macx {
    MACOSX_BUNDLE_ICON.files = mac/mac-mainicon.icns

    HEADERS += src/mac/activity.h src/mac/badgelabel.h
    OBJECTIVE_SOURCES += src/mac/activity.mm src/mac/badgelabel.mm
    CONFIG += x86
    QMAKE_TARGET_BUNDLE_PREFIX = live.koord
    # QMAKE_APPLICATION_BUNDLE_NAME. = $$TARGET

    QMAKE_INFO_PLIST = mac/Info-xcode.plist

    # handle differing entitlements - switch for dmg and Store builds
    contains(CONFIG, "appstore") {
        OSX_ENTITLEMENTS.files = mac/Koord-store.entitlements
        OSX_ENTITLEMENTS.path = Contents/Resources
        QMAKE_BUNDLE_DATA += OSX_ENTITLEMENTS
        XCODE_ENTITLEMENTS.name = CODE_SIGN_ENTITLEMENTS
        XCODE_ENTITLEMENTS.value = mac/Koord-store.entitlements
        QMAKE_MAC_XCODE_SETTINGS += XCODE_ENTITLEMENTS
    } else {
        OSX_ENTITLEMENTS.files = mac/Koord-dmg.entitlements
        OSX_ENTITLEMENTS.path = Contents/Resources
        QMAKE_BUNDLE_DATA += OSX_ENTITLEMENTS
        XCODE_ENTITLEMENTS.name = CODE_SIGN_ENTITLEMENTS
        XCODE_ENTITLEMENTS.value = mac/Koord-dmg.entitlements
        QMAKE_MAC_XCODE_SETTINGS += XCODE_ENTITLEMENTS
    }

    MACOSX_BUNDLE_ICON.path = Contents/Resources
    QMAKE_BUNDLE_DATA += MACOSX_BUNDLE_ICON

    LIBS += -framework CoreFoundation \
        -framework CoreServices \
        -framework CoreAudio \
        -framework CoreMIDI \
        -framework AudioToolbox \
        -framework AudioUnit \
        -framework Foundation \
        -framework AppKit

    # avoid macOS error: qt.tlsbackend.ossl: Failed to load libssl/libcrypto.
    LIBS += -L/usr/local/opt/openssl@1.1/lib
#    LIBS    += -lssl
#    LIBS    += -lcrypto

    # defo use CoreAudio and not Jack
    message(Using CoreAudio.)
    #HEADERS += mac/sound.h
    #SOURCES += mac/sound.cpp
    HEADERS += src/sound/coreaudio-mac/sound.h
    SOURCES += src/sound/coreaudio-mac/sound.cpp

} else:ios {
    # reset TARGET for iOS only since rename
    TARGET = Koord
    QMAKE_INFO_PLIST = ios/Info-xcode.plist
    # needed to fix "Error: You are creating QApplication before calling UIApplicationMain."
    QMAKE_LFLAGS += -Wl,-e,_qt_main_wrapper

    QMAKE_ASSET_CATALOGS += ios/Images.xcassets
    QMAKE_ASSET_CATALOGS_APP_ICON = "AppIcon"
    ios_icon.files = $$files($$PWD/ios/AppIcon*.png)
    QMAKE_BUNDLE_DATA += ios_icon

#    SOURCES += src/unsafearea.cpp
#    HEADERS += src/unsafearea.h
#    OBJECTIVE_SOURCES += ios/ios_app_delegate.mm
#    HEADERS += ios/ios_app_delegate.h
#    HEADERS += ios/sound.h
#    OBJECTIVE_SOURCES += ios/sound.mm
    HEADERS += src/sound/coreaudio-ios/sound.h
    OBJECTIVE_SOURCES += src/sound/coreaudio-ios/sound.mm

    # PRODUCT_BUNDLE_IDENTIFIER is set like
    #  ${PRODUCT_BUNDLE_IDENTIFIER} = QMAKE_TARGET_BUNDLE_PREFIX.QMAKE_BUNDLE
    QMAKE_TARGET_BUNDLE_PREFIX = live.koord
    QMAKE_BUNDLE = Koord-RT
    
    LIBS += -framework AVFoundation \
        -framework AudioToolbox

} else:android {
    # ANDROID_ABIS = armeabi-v7a arm64-v8a x86 x86_64
    # Build all targets, as per: https://developer.android.com/topic/arc/device-support

    # get ANDROID_ABIS from environment - passed directly to qmake
    ANDROID_ABIS = $$getenv(ANDROID_ABIS)

    # if ANDROID_ABIS is passed as env var to qmake, will override this
    # !defined(ANDROID_ABIS, var):ANDROID_ABIS = arm64-v8a

    # by default is 23 apparently = Android 6 !
    # BUT: crashes on Android 9, sdk=28
    ANDROID_MIN_SDK_VERSION = 29
    ANDROID_TARGET_SDK_VERSION = 32
    ANDROID_VERSION_NAME = $$VERSION

    ## FOR LOCAL DEV USE:
    equals(QMAKE_HOST.os, Windows) {
        ANDROID_ABIS = x86_64
        ANDROID_VERSION_CODE = 1234 # dummy int value
    } else {
        # date-based unique integer value for Play Store submission
        !defined(ANDROID_VERSION_CODE, var):ANDROID_VERSION_CODE = $$system(date +%s | cut -c 2-)
    }

    # make separate version codes for each abi build otherwise Play Store rejects
    contains (ANDROID_ABIS, armeabi-v7a) {
        ANDROID_VERSION_CODE = $$num_add($$ANDROID_VERSION_CODE, 1)
        message("Setting for armeabi-v7a: ANDROID_VERSION_CODE=$${ANDROID_VERSION_CODE}")
    }
    contains (ANDROID_ABIS, x86) {
        ANDROID_VERSION_CODE = $$num_add($$ANDROID_VERSION_CODE, 2)
        message("Setting for x86: ANDROID_VERSION_CODE=$${ANDROID_VERSION_CODE}")
    }
    contains (ANDROID_ABIS, x86_64) {
        ANDROID_VERSION_CODE = $$num_add($$ANDROID_VERSION_CODE, 3)
        message("Setting for x86_64: ANDROID_VERSION_CODE=$${ANDROID_VERSION_CODE}")
    }

    message("Setting ANDROID_VERSION_NAME=$${ANDROID_VERSION_NAME} ANDROID_VERSION_CODE=$${ANDROID_VERSION_CODE}")

    # liboboe requires C++17 for std::timed_mutex
    CONFIG += c++17

    # Need for eg device recording permissions
    QT += core-private
    # prob unnecesssary:
    QT += gui quick widgets quickwidgets

    # enabled only for debugging on android devices
    #DEFINES += ANDROIDDEBUG

    target.path = /tmp/your_executable # path on device
    INSTALLS += target

    HEADERS += src/sound/oboe/sound.h

    SOURCES += src/sound/oboe/sound.cpp \
        src/android/androiddebug.cpp

    LIBS += -lOpenSLES
    ANDROID_PACKAGE_SOURCE_DIR = $$PWD/android
    DISTFILES += android/AndroidManifest.xml

    # if compiling for android you need to use Oboe library which is included as a git submodule
    # make sure you git pull with submodules to pull the latest Oboe library
    OBOE_SOURCES = $$files(libs/oboe/src/*.cpp, true)
    OBOE_HEADERS = $$files(libs/oboe/src/*.h, true)

    INCLUDEPATH_OBOE = libs/oboe/include/ \
        libs/oboe/src/

    DISTFILES_OBOE += libs/oboe/AUTHORS \
        libs/oboe/CONTRIBUTING \
        libs/oboe/LICENSE \
        libs/oboe/README

    INCLUDEPATH += $$INCLUDEPATH_OBOE
    HEADERS += $$OBOE_HEADERS
    SOURCES += $$OBOE_SOURCES
    DISTFILES += $$DISTFILES_OBOE

    # add for OpenSSL 1 support
    include(android_openssl/openssl.pri)
} else:unix {
    # we want to compile with C++11
    CONFIG += c++11

    # Linux desktop does not have native web runtime, need to package
    QT += webenginecore
    # ??
    #QT += webenginequick

    # --as-needed avoids linking the final binary against unnecessary runtime
    # libs. Most g++ versions already do that by default.
    # However, Debian buster does not and would link against libQt5Concurrent
    # unnecessarily without this workaround (#741):
    QMAKE_LFLAGS += -Wl,--as-needed

    # we assume to have lrintf() one moderately modern linux distributions
    # would be better to have that tested, though
    DEFINES += HAVE_LRINTF

    # we assume that stdint.h is always present in a Linux system
    DEFINES += HAVE_STDINT_H

    # only include JACK support if CONFIG serveronly is not set
    contains(CONFIG, "serveronly") {
        message(Restricting build to server-only due to CONFIG+=serveronly.)
        DEFINES += SERVER_ONLY
    } else {
        message(JACK Audio Interface Enabled.)

        HEADERS += src/sound/jack/sound.h
        SOURCES += src/sound/jack/sound.cpp

        CONFIG += link_pkgconfig
        PKGCONFIG += jack
  
        DEFINES += WITH_JACK
    }

    isEmpty(PREFIX) {
        PREFIX = /usr/local
    }

    isEmpty(BINDIR) {
        BINDIR = bin
    }
    BINDIR = $$absolute_path($$BINDIR, $$PREFIX)
    target.path = $$BINDIR

    INSTALLS += target
}

RCC_DIR = src/res
RESOURCES += src/resources.qrc

#FORMS_GUI = src/serverdlgbase.ui

!contains(CONFIG, "serveronly") {
    FORMS_GUI += src/clientdlgbase.ui
}

HEADERS += src/buffer.h \
    src/channel.h \
    src/global.h \
    src/kdsingleapplication.h \
    src/protocol.h \
    src/recorder/jamcontroller.h \
    src/threadpool.h \
    src/server.h \
    src/serverlist.h \
    src/serverlogging.h \
    src/settings.h \
    src/socket.h \
    src/util.h \
    src/recorder/jamrecorder.h \
    src/recorder/creaperproject.h \
    src/recorder/cwavestream.h \
    src/signalhandler.h \
    src/kdapplication.h \
    src/urlhandler.h \
    src/messagereceiver.h

!contains(CONFIG, "serveronly") {
    HEADERS += src/client.h \
        src/sound/soundbase.h \
        src/testbench.h
}

#HEADERS_GUI = src/serverdlg.h

!contains(CONFIG, "serveronly") {
    HEADERS_GUI += src/audiomixerboard.h \
        src/clientdlg.h \
        src/levelmeter.h \
        src/analyzerconsole.h \
        src/multicolorled.h
}

HEADERS_OPUS = libs/opus/celt/arch.h \
    libs/opus/celt/bands.h \
    libs/opus/celt/celt.h \
    libs/opus/celt/celt_lpc.h \
    libs/opus/celt/cpu_support.h \
    libs/opus/celt/cwrs.h \
    libs/opus/celt/ecintrin.h \
    libs/opus/celt/entcode.h \
    libs/opus/celt/entdec.h \
    libs/opus/celt/entenc.h \
    libs/opus/celt/float_cast.h \
    libs/opus/celt/kiss_fft.h \
    libs/opus/celt/laplace.h \
    libs/opus/celt/mathops.h \
    libs/opus/celt/mdct.h \
    libs/opus/celt/mfrngcod.h \
    libs/opus/celt/modes.h \
    libs/opus/celt/os_support.h \
    libs/opus/celt/pitch.h \
    libs/opus/celt/quant_bands.h \
    libs/opus/celt/rate.h \
    libs/opus/celt/stack_alloc.h \
    libs/opus/celt/static_modes_float.h \
    libs/opus/celt/vq.h \
    libs/opus/celt/_kiss_fft_guts.h \
    libs/opus/include/opus.h \
    libs/opus/include/opus_custom.h \
    libs/opus/include/opus_defines.h \
    libs/opus/include/opus_types.h \
    libs/opus/silk/API.h \
    libs/opus/silk/control.h \
    libs/opus/silk/debug.h \
    libs/opus/silk/define.h \
    libs/opus/silk/errors.h \
    libs/opus/silk/float/main_FLP.h \
    libs/opus/silk/float/SigProc_FLP.h \
    libs/opus/silk/float/structs_FLP.h \
    libs/opus/silk/Inlines.h \
    libs/opus/silk/MacroCount.h \
    libs/opus/silk/MacroDebug.h \
    libs/opus/silk/macros.h \
    libs/opus/silk/main.h \
    libs/opus/silk/NSQ.h \
    libs/opus/silk/pitch_est_defines.h \
    libs/opus/silk/PLC.h \
    libs/opus/silk/resampler_private.h \
    libs/opus/silk/resampler_rom.h \
    libs/opus/silk/resampler_structs.h \
    libs/opus/silk/SigProc_FIX.h \
    libs/opus/silk/structs.h \
    libs/opus/silk/tables.h \
    libs/opus/silk/tuning_parameters.h \
    libs/opus/silk/typedef.h \
    libs/opus/src/analysis.h \
    libs/opus/src/mlp.h \
    libs/opus/src/opus_private.h \
    libs/opus/src/tansig_table.h

HEADERS_OPUS_ARM = libs/opus/celt/arm/armcpu.h \
    libs/opus/silk/arm/biquad_alt_arm.h \
    libs/opus/celt/arm/fft_arm.h \
    libs/opus/silk/arm/LPC_inv_pred_gain_arm.h \
    libs/opus/celt/arm/mdct_arm.h \
    libs/opus/silk/arm/NSQ_del_dec_arm.h \
    libs/opus/celt/arm/pitch_arm.h

HEADERS_OPUS_X86 = libs/opus/celt/x86/celt_lpc_sse.h \
    libs/opus/celt/x86/pitch_sse.h \
    libs/opus/celt/x86/vq_sse.h \
    libs/opus/celt/x86/x86cpu.h \
    $$files(libs/opus/silk/x86/*.h)

SOURCES += src/buffer.cpp \
    src/channel.cpp \
    src/kdapplication.cpp \
    src/kdsingleapplication.cpp \
    src/main.cpp \
    src/protocol.cpp \
    src/recorder/jamcontroller.cpp \
    src/server.cpp \
    src/serverlist.cpp \
    src/serverlogging.cpp \
    src/settings.cpp \
    src/signalhandler.cpp \
    src/socket.cpp \
    src/util.cpp \
    src/recorder/jamrecorder.cpp \
    src/recorder/creaperproject.cpp \
    src/recorder/cwavestream.cpp \
    src/urlhandler.cpp \
    src/messagereceiver.cpp

!contains(CONFIG, "serveronly") {
    SOURCES += src/client.cpp \
        src/sound/soundbase.cpp \
}

#SOURCES_GUI = src/serverdlg.cpp

!contains(CONFIG, "serveronly") {
    SOURCES_GUI += src/audiomixerboard.cpp \
        src/clientdlg.cpp \
        src/multicolorled.cpp \
        src/levelmeter.cpp \
        src/analyzerconsole.cpp
}

SOURCES_OPUS = libs/opus/celt/bands.c \
    libs/opus/celt/celt.c \
    libs/opus/celt/celt_decoder.c \
    libs/opus/celt/celt_encoder.c \
    libs/opus/celt/celt_lpc.c \
    libs/opus/celt/cwrs.c \
    libs/opus/celt/entcode.c \
    libs/opus/celt/entdec.c \
    libs/opus/celt/entenc.c \
    libs/opus/celt/kiss_fft.c \
    libs/opus/celt/laplace.c \
    libs/opus/celt/mathops.c \
    libs/opus/celt/mdct.c \
    libs/opus/celt/modes.c \
    libs/opus/celt/pitch.c \
    libs/opus/celt/quant_bands.c \
    libs/opus/celt/rate.c \
    libs/opus/celt/vq.c \
    libs/opus/silk/A2NLSF.c \
    libs/opus/silk/ana_filt_bank_1.c \
    libs/opus/silk/biquad_alt.c \
    libs/opus/silk/bwexpander.c \
    libs/opus/silk/bwexpander_32.c \
    libs/opus/silk/check_control_input.c \
    libs/opus/silk/CNG.c \
    libs/opus/silk/code_signs.c \
    libs/opus/silk/control_audio_bandwidth.c \
    libs/opus/silk/control_codec.c \
    libs/opus/silk/control_SNR.c \
    libs/opus/silk/debug.c \
    libs/opus/silk/decoder_set_fs.c \
    libs/opus/silk/decode_core.c \
    libs/opus/silk/decode_frame.c \
    libs/opus/silk/decode_indices.c \
    libs/opus/silk/decode_parameters.c \
    libs/opus/silk/decode_pitch.c \
    libs/opus/silk/decode_pulses.c \
    libs/opus/silk/dec_API.c \
    libs/opus/silk/encode_indices.c \
    libs/opus/silk/encode_pulses.c \
    libs/opus/silk/enc_API.c \
    libs/opus/silk/float/apply_sine_window_FLP.c \
    libs/opus/silk/float/autocorrelation_FLP.c \
    libs/opus/silk/float/burg_modified_FLP.c \
    libs/opus/silk/float/bwexpander_FLP.c \
    libs/opus/silk/float/corrMatrix_FLP.c \
    libs/opus/silk/float/encode_frame_FLP.c \
    libs/opus/silk/float/energy_FLP.c \
    libs/opus/silk/float/find_LPC_FLP.c \
    libs/opus/silk/float/find_LTP_FLP.c \
    libs/opus/silk/float/find_pitch_lags_FLP.c \
    libs/opus/silk/float/find_pred_coefs_FLP.c \
    libs/opus/silk/float/inner_product_FLP.c \
    libs/opus/silk/float/k2a_FLP.c \
    libs/opus/silk/float/LPC_analysis_filter_FLP.c \
    libs/opus/silk/float/LTP_analysis_filter_FLP.c \
    libs/opus/silk/float/LTP_scale_ctrl_FLP.c \
    libs/opus/silk/float/noise_shape_analysis_FLP.c \
    libs/opus/silk/float/pitch_analysis_core_FLP.c \
    libs/opus/silk/float/process_gains_FLP.c \
    libs/opus/silk/float/residual_energy_FLP.c \
    libs/opus/silk/float/scale_copy_vector_FLP.c \
    libs/opus/silk/float/scale_vector_FLP.c \
    libs/opus/silk/float/schur_FLP.c \
    libs/opus/silk/float/sort_FLP.c \
    libs/opus/silk/float/warped_autocorrelation_FLP.c \
    libs/opus/silk/float/wrappers_FLP.c \
    libs/opus/silk/gain_quant.c \
    libs/opus/silk/HP_variable_cutoff.c \
    libs/opus/silk/init_decoder.c \
    libs/opus/silk/init_encoder.c \
    libs/opus/silk/inner_prod_aligned.c \
    libs/opus/silk/interpolate.c \
    libs/opus/silk/lin2log.c \
    libs/opus/silk/log2lin.c \
    libs/opus/silk/LPC_analysis_filter.c \
    libs/opus/silk/LPC_fit.c \
    libs/opus/silk/LPC_inv_pred_gain.c \
    libs/opus/silk/LP_variable_cutoff.c \
    libs/opus/silk/NLSF2A.c \
    libs/opus/silk/NLSF_decode.c \
    libs/opus/silk/NLSF_del_dec_quant.c \
    libs/opus/silk/NLSF_encode.c \
    libs/opus/silk/NLSF_stabilize.c \
    libs/opus/silk/NLSF_unpack.c \
    libs/opus/silk/NLSF_VQ.c \
    libs/opus/silk/NLSF_VQ_weights_laroia.c \
    libs/opus/silk/NSQ.c \
    libs/opus/silk/NSQ_del_dec.c \
    libs/opus/silk/pitch_est_tables.c \
    libs/opus/silk/PLC.c \
    libs/opus/silk/process_NLSFs.c \
    libs/opus/silk/quant_LTP_gains.c \
    libs/opus/silk/resampler.c \
    libs/opus/silk/resampler_down2.c \
    libs/opus/silk/resampler_down2_3.c \
    libs/opus/silk/resampler_private_AR2.c \
    libs/opus/silk/resampler_private_down_FIR.c \
    libs/opus/silk/resampler_private_IIR_FIR.c \
    libs/opus/silk/resampler_private_up2_HQ.c \
    libs/opus/silk/resampler_rom.c \
    libs/opus/silk/shell_coder.c \
    libs/opus/silk/sigm_Q15.c \
    libs/opus/silk/sort.c \
    libs/opus/silk/stereo_decode_pred.c \
    libs/opus/silk/stereo_encode_pred.c \
    libs/opus/silk/stereo_find_predictor.c \
    libs/opus/silk/stereo_LR_to_MS.c \
    libs/opus/silk/stereo_MS_to_LR.c \
    libs/opus/silk/stereo_quant_pred.c \
    libs/opus/silk/sum_sqr_shift.c \
    libs/opus/silk/tables_gain.c \
    libs/opus/silk/tables_LTP.c \
    libs/opus/silk/tables_NLSF_CB_NB_MB.c \
    libs/opus/silk/tables_NLSF_CB_WB.c \
    libs/opus/silk/tables_other.c \
    libs/opus/silk/tables_pitch_lag.c \
    libs/opus/silk/tables_pulses_per_block.c \
    libs/opus/silk/table_LSF_cos.c \
    libs/opus/silk/VAD.c \
    libs/opus/silk/VQ_WMat_EC.c \
    libs/opus/src/analysis.c \
    libs/opus/src/mlp.c \
    libs/opus/src/mlp_data.c \
    libs/opus/src/opus.c \
    libs/opus/src/opus_decoder.c \
    libs/opus/src/opus_encoder.c \
    libs/opus/src/repacketizer.c

SOURCES_OPUS_ARM = libs/opus/celt/arm/armcpu.c \
    libs/opus/celt/arm/arm_celt_map.c \
    libs/opus/silk/arm/arm_silk_map.c \
    libs/opus/silk/arm/arm_silk_map.c \
    libs/opus/silk/arm/biquad_alt_neon_intr.c \
    libs/opus/silk/arm/LPC_inv_pred_gain_neon_intr.c \
    libs/opus/silk/arm/NSQ_del_dec_neon_intr.c \
    libs/opus/silk/arm/NSQ_neon.c \
    libs/opus/celt/arm/celt_neon_intr.c \
    libs/opus/celt/arm/pitch_neon_intr.c \
    libs/opus/celt/arm/celt_fft_ne10.c \
    libs/opus/celt/arm/celt_mdct_ne10.c

SOURCES_OPUS_X86_SSE = libs/opus/celt/x86/x86cpu.c \
    libs/opus/celt/x86/x86_celt_map.c \
    libs/opus/celt/x86/pitch_sse.c
SOURCES_OPUS_X86_SSE2 = libs/opus/celt/x86/pitch_sse2.c \
     libs/opus/celt/x86/vq_sse2.c
SOURCES_OPUS_X86_SSE4 = libs/opus/celt/x86/celt_lpc_sse4_1.c \
     libs/opus/celt/x86/pitch_sse4_1.c \
     libs/opus/silk/x86/NSQ_sse4_1.c \
     libs/opus/silk/x86/NSQ_del_dec_sse4_1.c \
     libs/opus/silk/x86/x86_silk_map.c \
     libs/opus/silk/x86/VAD_sse4_1.c \
     libs/opus/silk/x86/VQ_WMat_EC_sse4_1.c

contains(QT_ARCH, armeabi-v7a) | contains(QT_ARCH, arm64-v8a) {
    HEADERS_OPUS += $$HEADERS_OPUS_ARM
    SOURCES_OPUS_ARCH += $$SOURCES_OPUS_ARM
    DEFINES_OPUS += OPUS_ARM_PRESUME_NEON=1 OPUS_ARM_PRESUME_NEON_INTR=1
    contains(QT_ARCH, arm64-v8a):DEFINES_OPUS += OPUS_ARM_PRESUME_AARCH64_NEON_INTR
} else:contains(QT_ARCH, x86) | contains(QT_ARCH, x86_64) {
    HEADERS_OPUS += $$HEADERS_OPUS_X86
    SOURCES_OPUS_ARCH += $$SOURCES_OPUS_X86_SSE $$SOURCES_OPUS_X86_SSE2 $$SOURCES_OPUS_X86_SSE4
    DEFINES_OPUS += OPUS_X86_MAY_HAVE_SSE OPUS_X86_MAY_HAVE_SSE2 OPUS_X86_MAY_HAVE_SSE4_1
    # x86_64 implies SSE2
    contains(QT_ARCH, x86_64):DEFINES_OPUS += OPUS_X86_PRESUME_SSE=1 OPUS_X86_PRESUME_SSE2=1
    DEFINES_OPUS += CPU_INFO_BY_C
}
DEFINES_OPUS += OPUS_BUILD=1 USE_ALLOCA=1 OPUS_HAVE_RTCD=1 HAVE_LRINTF=1 HAVE_LRINT=1

DISTFILES += ChangeLog \
    COPYING \
    CONTRIBUTING.md \
    README.md \
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

DISTFILES_OPUS += libs/opus/AUTHORS \
    libs/opus/ChangeLog \
    libs/opus/COPYING \
    libs/opus/INSTALL \
    libs/opus/NEWS \
    libs/opus/README \
    libs/opus/celt/arm/armopts.s.in \
    libs/opus/celt/arm/celt_pitch_xcorr_arm.s \

contains(CONFIG, "headless") {
    DEFINES += HEADLESS
} else {
    HEADERS += $$HEADERS_GUI
    SOURCES += $$SOURCES_GUI
    FORMS += $$FORMS_GUI
}

contains(CONFIG, "nojsonrpc") {
    message(JSON-RPC support excluded from build.)
    DEFINES += NO_JSON_RPC
} else {
    HEADERS += \
        src/rpcserver.h \
        src/serverrpc.h
    SOURCES += \
        src/rpcserver.cpp \
        src/serverrpc.cpp
    contains(CONFIG, "serveronly") {
        message("server only, skipping client rpc")
    } else {
        HEADERS += src/clientrpc.h
        SOURCES += src/clientrpc.cpp
    }
}

# use external OPUS library if requested
contains(CONFIG, "opus_shared_lib") {
    message(OPUS codec is used from a shared library.)

    unix {
        !exists(/usr/include/opus/opus_custom.h) {
            !exists(/usr/local/include/opus/opus_custom.h) {
                 message(Header opus_custom.h was not found at the usual place. Maybe the opus dev packet is missing.)
            }
        }

        LIBS += -lopus
        DEFINES += USE_OPUS_SHARED_LIB
    }
} else {
    DEFINES += $$DEFINES_OPUS
    INCLUDEPATH += $$INCLUDEPATH_OPUS
    HEADERS += $$HEADERS_OPUS
    SOURCES += $$SOURCES_OPUS
    DISTFILES += $$DISTFILES_OPUS

    contains(QT_ARCH, x86) | contains(QT_ARCH, x86_64) {
        msvc {
            # According to opus/win32/config.h, "no special compiler
            # flags necessary" when using msvc.  It always supports
            # SSE intrinsics, but does not auto-vectorize.
            SOURCES += $$SOURCES_OPUS_ARCH
        } else {
            # Arch-specific files need special compiler flags, but we
            # can't use those flags for other files because otherwise we
            # might end up with vectorized code that the CPU doesn't
            # support.  For windows, libs/opus/win32/config.h says no
            # compiler flags are needed.
            sse_cc.name = sse_cc
            sse_cc.input = SOURCES_OPUS_X86_SSE
            sse_cc.dependency_type = TYPE_C
            sse_cc.output = ${QMAKE_FILE_IN_BASE}$${first(QMAKE_EXT_OBJ)}
            sse_cc.commands = ${CC} -msse $(CFLAGS) $(INCPATH) -c ${QMAKE_FILE_IN} -o ${QMAKE_FILE_OUT}
            sse_cc.variable_out = OBJECTS
            sse2_cc.name = sse2_cc
            sse2_cc.input = SOURCES_OPUS_X86_SSE2
            sse2_cc.dependency_type = TYPE_C
            sse2_cc.output = ${QMAKE_FILE_IN_BASE}$${first(QMAKE_EXT_OBJ)}
            sse2_cc.commands = ${CC} -msse2 $(CFLAGS) $(INCPATH) -c ${QMAKE_FILE_IN} -o ${QMAKE_FILE_OUT}
            sse2_cc.variable_out = OBJECTS
            sse4_cc.name = sse4_cc
            sse4_cc.input = SOURCES_OPUS_X86_SSE4
            sse4_cc.dependency_type = TYPE_C
            sse4_cc.output = ${QMAKE_FILE_IN_BASE}$${first(QMAKE_EXT_OBJ)}
            sse4_cc.commands = ${CC} -msse4 $(CFLAGS) $(INCPATH) -c ${QMAKE_FILE_IN} -o ${QMAKE_FILE_OUT}
            sse4_cc.variable_out = OBJECTS
            QMAKE_EXTRA_COMPILERS += sse_cc sse2_cc sse4_cc
        }
    }
}

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
