/******************************************************************************\
 * Copyright (c) 2004-2022
 *
 * Author(s):
 *  Volker Fischer
 *
 ******************************************************************************
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation; either version 2 of the License, or (at your option) any later
 * version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA
 *
\******************************************************************************/

#pragma once

#include "qnetworkaccessmanager.h"
#include "qnetworkreply.h"
//#include "urlhandler.h"
#include <QLabel>
#include <QString>
#include <QLineEdit>
#include <QPushButton>
#include <QProgressBar>
#include <QWhatsThis>
#include <QTimer>
#include <QSlider>
#include <QRadioButton>
#include <QMenuBar>
#include <QButtonGroup>
#include <QLayout>
#include <QMessageBox>
#include <QFileDialog>
#include <QActionGroup>
#include <QMainWindow>
//#include <QSoundEffect>
#if QT_VERSION >= QT_VERSION_CHECK( 5, 6, 0 )
#    include <QVersionNumber>
#endif
//#include "global.h"
#include "util.h"
#include "client.h"
#include "settings.h"
#include "multicolorled.h"
#include "audiomixerboard.h"
#include "analyzerconsole.h"
#include "ui_clientdlgbase.h"
#if defined( Q_OS_MACOS )
#    include "mac/badgelabel.h"
#endif
#include <QQuickWidget>
#include <QQuickView>
//#include "unsafearea.h"

/* Definitions ****************************************************************/
// update time for GUI controls
#define LEVELMETER_UPDATE_TIME_MS  100  // ms
#define BUFFER_LED_UPDATE_TIME_MS  300  // ms
#define LED_BAR_UPDATE_TIME_MS     1000 // ms
#define CHECK_AUDIO_DEV_OK_TIME_MS 5000 // ms
#define DETECT_FEEDBACK_TIME_MS    3000 // ms

// number of ping times > upper bound until error message is shown
#define NUM_HIGH_PINGS_UNTIL_ERROR 5

#define DISPLAY_UPDATE_TIME 1000 // ms

#define SERV_LIST_REQ_UPDATE_TIME_MS 2000 // ms

/* Classes ********************************************************************/
class CClientDlg : public QMainWindow, private Ui_CClientDlgBase
{
    Q_OBJECT
    Q_PROPERTY( QString video_url READ getVideoUrl NOTIFY videoUrlChanged )


public:
    CClientDlg ( CClient*         pNCliP,
                 CClientSettings* pNSetP,
                 const QString&   strConnOnStartupAddress,
                 const QString&   strMIDISetup,
                 const bool       bNewShowComplRegConnList,
                 const bool       bShowAnalyzerConsole,
                 const bool       bMuteStream,
                 const bool       bNEnableIPv6,
                 QWidget*         parent = nullptr );
//    // session chat
//    void AddChatText ( QString strChatText );
    // settings
    void UpdateUploadRate();
    void UpdateDisplay();
    void UpdateSettingsDisplay();
    void UpdateSoundDeviceChannelSelectionFrame();
    void SetEnableFeedbackDetection ( bool enable );

    // for QML
    QString getVideoUrl() const {
        qInfo() << ">>> Calling getVideoUrl and returning value: " << strVideoUrl;
        return strVideoUrl;
    };

    // region checker stuff
    void SetShowAllMusicians ( const bool bState ) { ShowAllMusicians ( bState ); }
    bool GetShowAllMusicians() { return bShowAllMusicians; }
    void SetServerList ( const CHostAddress& InetAddr, const CVector<CServerInfo>& vecServerInfo, const bool bIsReducedServerList = false );
    void SetConnClientsList ( const CHostAddress& InetAddr, const CVector<CChannelInfo>& vecChanInfo );
    void SetPingTimeAndNumClientsResult ( const CHostAddress& InetAddr, const int iPingTime, const int iNumClients );
    bool    GetServerListItemWasChosen() const { return bServerListItemWasChosen; }
    QString GetSelectedAddress() const { return strSelectedAddress; }
    QString GetSelectedServerName() const { return strSelectedServerName; }

protected:
    void SetGUIDesign ( const EGUIDesign eNewDesign );
    void SetMeterStyle ( const EMeterStyle eNewMeterStyle );
    void SetMyWindowTitle ( const int iNumClients );
//    void ShowConnectionSetupDialog();
//    void ShowBasicConnectionSetupDialog();
    void ShowJoinWidget();
    void HideJoinWidget();
    void ShowGeneralSettings ( int iTab );
    void ShowChatWindow ( const bool bForceRaise = true );
    void ShowAnalyzerConsole();
    void UpdateAudioFaderSlider();
    void UpdateRevSelection();
    void Connect ( const QString& strSelectedAddress, const QString& strMixerBoardLabel );
    void Disconnect();
    void ManageDragNDrop ( QDropEvent* Event, const bool bCheckAccept );
    void SetPingTime ( const int iPingTime, const int iOverallDelayMs, const CMultiColorLED::ELightColor eOverallDelayLEDColor );

    CClient*         pClient;
    CClientSettings* pSettings;
//    UnsafeArea*    mUnsafeArea;

    int            iClients;
    bool           bConnected;
    bool           bConnectDlgWasShown;
//    bool           bBasicConnectDlgWasShown;
    bool           bMIDICtrlUsed;
    bool           bDetectFeedback;
    bool           bEnableIPv6;
    ERecorderState eLastRecorderState;
    EGUIDesign     eLastDesign;
    QTimer         TimerSigMet;
    QTimer         TimerBuffersLED;
    QTimer         TimerStatus;
    QTimer         TimerPing;
    QTimer         TimerCheckAudioDeviceOk;
    QTimer         TimerDetectFeedback;
    // for join
    QString        strSelectedAddress;
    QString        strVideoUrl;
    QString        strVideoHost;
    QString        strSessionHash;
#if defined(Q_OS_ANDROID)
    QQuickWidget*   quickWidget;
#else
    QQuickView*     quickView;
#endif
    QNetworkAccessManager*   qNam;

    virtual void closeEvent ( QCloseEvent* Event );
    virtual void dragEnterEvent ( QDragEnterEvent* Event ) { ManageDragNDrop ( Event, true ); }
    virtual void dropEvent ( QDropEvent* Event ) { ManageDragNDrop ( Event, false ); }

    CAnalyzerConsole   AnalyzerConsole;

    // settings stuff
    void    UpdateJitterBufferFrame();
    void    UpdateSoundCardFrame();
    void    UpdateDirectoryServerComboBox();
//    void    UpdateAudioFaderSlider();
    QString GenSndCrdBufferDelayString ( const int iFrameSize, const QString strAddText = "" );
    virtual void showEvent ( QShowEvent* );
//    CClient*         pClient;
//    CClientSettings* pSettings;
//    QTimer           TimerStatus;
    QButtonGroup     SndCrdBufferDelayButtonGroup;

    // regionchecker stuff
//    virtual void showEvent ( QShowEvent* );
//    virtual void hideEvent ( QHideEvent* );
    QTreeWidgetItem* FindListViewItem ( const CHostAddress& InetAddr );
    QTreeWidgetItem* GetParentListViewItem ( QTreeWidgetItem* pItem );
    void             DeleteAllListViewItemChilds ( QTreeWidgetItem* pItem );
    void             UpdateListFilter();
    void             ShowAllMusicians ( const bool bState );
    void             RequestServerList();
    void             EmitCLServerListPingMes ( const CHostAddress& haServerAddress );
//    void             UpdateDirectoryServerComboBox();
//    CClientSettings* pSettings;
    QTimer       RegionTimerPing;
    QTimer       TimerReRequestServList;
    QTimer       TimerInitialSort;
    CHostAddress haDirectoryAddress;
    QString      strSelectedServerName;
    bool         bShowCompleteRegList;
    bool         bServerListReceived;
    bool         bReducedServerListReceived;
    bool         bServerListItemWasChosen;
    bool         bListFilterWasActive;
    bool         bShowAllMusicians;
//    bool         bEnableIPv6;

    // for urlhandler
//    UrlHandler* url_handler;

public slots:
    void OnConnectDisconBut();
    void OnInviteBoxActivated();
    void OnNewStartClicked();
    void OnTimerSigMet();
    void OnTimerBuffersLED();
    void OnTimerCheckAudioDeviceOk();
    void OnTimerDetectFeedback();

    void replyFinished(QNetworkReply *rep);

    void OnTimerStatus() { UpdateDisplay(); }

    void OnTimerPing();
    void OnPingTimeResult ( int iPingTime );
    void OnCLPingTimeWithNumClientsReceived ( CHostAddress InetAddr, int iPingTime, int iNumClients );

    void OnControllerInFaderLevel ( const int iChannelIdx, const int iValue ) { MainMixerBoard->SetFaderLevel ( iChannelIdx, iValue ); }

    void OnControllerInPanValue ( const int iChannelIdx, const int iValue ) { MainMixerBoard->SetPanValue ( iChannelIdx, iValue ); }

    void OnControllerInFaderIsSolo ( const int iChannelIdx, const bool bIsSolo ) { MainMixerBoard->SetFaderIsSolo ( iChannelIdx, bIsSolo ); }

    void OnControllerInFaderIsMute ( const int iChannelIdx, const bool bIsMute ) { MainMixerBoard->SetFaderIsMute ( iChannelIdx, bIsMute ); }

    void OnControllerInMuteMyself ( const bool bMute ) { chbLocalMute->setChecked ( bMute ); }

    void OnVersionAndOSReceived ( COSUtil::EOpSystemType, QString strVersion );

    void OnCLVersionAndOSReceived ( CHostAddress, COSUtil::EOpSystemType, QString strVersion );

    void OnLoadChannelSetup();
    void OnSaveChannelSetup();
//    void OnOpenConnectionSetupDialog() { ShowBasicConnectionSetupDialog(); }
//    void OnOpenUserProfileSettings();
//    void OnOpenAudioNetSettings();
//    void OnOpenAdvancedSettings();
//    void OnOpenChatDialog() { ShowChatWindow(); }
    void OnOpenAnalyzerConsole() { ShowAnalyzerConsole(); }
    void OnOwnFaderFirst()
    {
        pSettings->bOwnFaderFirst = !pSettings->bOwnFaderFirst;
        MainMixerBoard->SetFaderSorting ( pSettings->eChannelSortType );
    }
    void OnNoSortChannels() { MainMixerBoard->SetFaderSorting ( ST_NO_SORT ); }
    void OnSortChannelsByName() { MainMixerBoard->SetFaderSorting ( ST_BY_NAME ); }
//    void OnSortChannelsByInstrument() { MainMixerBoard->SetFaderSorting ( ST_BY_INSTRUMENT ); }
    void OnSortChannelsByGroupID() { MainMixerBoard->SetFaderSorting ( ST_BY_GROUPID ); }
//    void OnSortChannelsByCity() { MainMixerBoard->SetFaderSorting ( ST_BY_CITY ); }
    void OnClearAllStoredSoloMuteSettings();
    void OnSetAllFadersToNewClientLevel() { MainMixerBoard->SetAllFaderLevelsToNewClientLevel(); }
    void OnAutoAdjustAllFaderLevels() { MainMixerBoard->AutoAdjustAllFaderLevels(); }
    void OnNumMixerPanelRowsChanged ( int value ) { MainMixerBoard->SetNumMixerPanelRows ( value ); }

    void OnSettingsStateChanged ( int value );
//    void OnPubConnectStateChanged ( int value );
    void OnChatStateChanged ( int value );
    void OnLocalMuteStateChanged ( int value );

    void OnAudioReverbValueChanged ( int value ) { pClient->SetReverbLevel ( value ); }

    void OnReverbSelLClicked() { pClient->SetReverbOnLeftChan ( true ); }

    void OnReverbSelRClicked() { pClient->SetReverbOnLeftChan ( false ); }

//    void OnFeedbackDetectionChanged ( int state ) { SetEnableFeedbackDetection ( state == Qt::Checked ); }

    void OnConClientListMesReceived ( CVector<CChannelInfo> vecChanInfo );
//    void OnChatTextReceived ( QString strChatText );
//    void OnLicenceRequired ( ELicenceType eLicenceType );
    void OnSoundDeviceChanged ( QString strError );

    void OnChangeChanGain ( int iId, float fGain, bool bIsMyOwnFader ) { pClient->SetRemoteChanGain ( iId, fGain, bIsMyOwnFader ); }

    void OnChangeChanPan ( int iId, float fPan ) { pClient->SetRemoteChanPan ( iId, fPan ); }

    void OnNewLocalInputText ( QString strChatText ) { pClient->CreateChatTextMes ( strChatText ); }

    void OnReqServerListQuery ( CHostAddress InetAddr ) { pClient->CreateCLReqServerListMes ( InetAddr ); }

    void OnCreateCLServerListPingMes ( CHostAddress InetAddr ) { pClient->CreateCLServerListPingMes ( InetAddr ); }

    void OnCreateCLServerListReqVerAndOSMes ( CHostAddress InetAddr ) { pClient->CreateCLServerListReqVerAndOSMes ( InetAddr ); }

    void OnCreateCLServerListReqConnClientsListMes ( CHostAddress InetAddr ) { pClient->CreateCLServerListReqConnClientsListMes ( InetAddr ); }

     void OnCLServerListReceived ( CHostAddress InetAddr, CVector<CServerInfo> vecServerInfo )
     {
         SetServerList ( InetAddr, vecServerInfo );
     }

     void OnCLRedServerListReceived ( CHostAddress InetAddr, CVector<CServerInfo> vecServerInfo )
     {
         SetServerList ( InetAddr, vecServerInfo, true );
     }

     void OnCLConnClientsListMesReceived ( CHostAddress InetAddr, CVector<CChannelInfo> vecChanInfo )
     {
         SetConnClientsList ( InetAddr, vecChanInfo );
     }

    void OnClientIDReceived ( int iChanID ) { MainMixerBoard->SetMyChannelID ( iChanID ); }

    void OnMuteStateHasChangedReceived ( int iChanID, bool bIsMuted ) { MainMixerBoard->SetRemoteFaderIsMute ( iChanID, bIsMuted ); }

    void OnCLChannelLevelListReceived ( CHostAddress /* unused */, CVector<uint16_t> vecLevelList )
    {
        MainMixerBoard->SetChannelLevels ( vecLevelList );
    }

    void OnJoinCancelClicked();
    void OnEventJoinConnectClicked ( const QString& url );
    void OnJoinConnectClicked();
//    void OnBasicConnectDlgAccepted();
//    void OnConnectDlgAccepted();
    void OnDisconnected() { Disconnect(); }
    void OnGUIDesignChanged();
    void OnMeterStyleChanged();
    void OnRecorderStateReceived ( ERecorderState eRecorderState );
    void SetMixerBoardDeco ( const ERecorderState newRecorderState, const EGUIDesign eNewDesign );
    void OnAudioChannelsChanged() { UpdateRevSelection(); }
    void OnNumClientsChanged ( int iNewNumClients );

    // updates
    void OnCheckForUpdate();
    void OnDownloadUpdateClicked();

//    // session chat stuff ========================
//    void OnSendText();
//    void OnLocalInputTextTextChanged ( const QString& strNewText );
//    void OnClearChatHistory();
//    void OnAnchorClicked ( const QUrl& Url );
//    // end session chat stuff ========================

    // settings stuff ==========================================
//    void OnTimerStatus() { UpdateDisplay(); }
    void OnNetBufValueChanged ( int value );
    void OnNetBufServerValueChanged ( int value );
    void OnAutoJitBufStateChanged ( int value );
    void OnEnableOPUS64StateChanged ( int value );
    void OnFeedbackDetectionChanged ( int value );
    void OnCustomDirectoriesEditingFinished();
    void OnNewClientLevelEditingFinished() { pSettings->iNewClientFaderLevel = edtNewClientLevel->text().toInt(); }
    void OnNewClientLevelChanged();
    void OnInputBoostChanged();
    void OnSndCrdBufferDelayButtonGroupClicked ( QAbstractButton* button );
    void OnSoundcardActivated ( int iSndDevIdx );
    void OnLInChanActivated ( int iChanIdx );
    void OnRInChanActivated ( int iChanIdx );
    void OnLOutChanActivated ( int iChanIdx );
    void OnROutChanActivated ( int iChanIdx );
    void OnAudioChannelsActivated ( int iChanIdx );
    void OnAudioQualityActivated ( int iQualityIdx );
    void OnGUIDesignActivated ( int iDesignIdx );
    void OnMeterStyleActivated ( int iMeterStyleIdx );
    void OnLanguageChanged ( QString strLanguage ) { pSettings->strLanguage = strLanguage; }
    void OnAliasTextChanged ( const QString& strNewName );
//    void OnInstrumentActivated ( int iCntryListItem );
//    void OnCountryActivated ( int iCntryListItem );
//    void OnCityTextChanged ( const QString& strNewName );
//    void OnSkillActivated ( int iCntryListItem );
//    void OnTabChanged();
//    void OnMakeTabChange ( int iTabIdx );
    void OnAudioPanValueChanged ( int value );
#if defined( _WIN32 ) && !defined( WITH_JACK )
    // Only include this slot for Windows when JACK is NOT used
    void OnDriverSetupClicked();
#endif
    // end of settings stuff ===================================

    void accept() { close(); } // introduced by pljones


    // regionchecker stuff
//    void OnServerListItemDoubleClicked ( QTreeWidgetItem* Item, int );
    void OnServerAddrEditTextChanged ( const QString& );
    void OnDirectoryServerChanged ( int iTypeIdx );
//    void OnFilterTextEdited ( const QString& ) { UpdateListFilter(); }
//    void OnExpandAllStateChanged ( int value ) { ShowAllMusicians ( value == Qt::Checked ); }
    void OnCustomDirectoriesChanged();
//    void OnConnectClicked();
    void OnRegionTimerPing();
    void OnTimerReRequestServList();

    void OnConnectFromURLHandler(const QString& connect_url);
//    void setDefaultSingleUserMode(const QString& value);

signals:
    void SendTabChange ( int iTabIdx );
    void NewLocalInputText ( QString strNewText );

    // settings stuff
    void GUIDesignChanged();
    void MeterStyleChanged();
    void AudioChannelsChanged();
    void CustomDirectoriesChanged();
    void NumMixerPanelRowsChanged ( int value );

    // for QML
    void videoUrlChanged();

    //region checker stuff
    void ReqServerListQuery ( CHostAddress InetAddr );
    void CreateCLServerListPingMes ( CHostAddress InetAddr );
    void CreateCLServerListReqVerAndOSMes ( CHostAddress InetAddr );
    void CreateCLServerListReqConnClientsListMes ( CHostAddress InetAddr );

    // custom macOS url handler stuff
    void EventJoinConnectClicked( const QString &url );
};
