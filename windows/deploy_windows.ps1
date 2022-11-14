param (
    [string] $APP_BUILD_VERSION = "1.0.0",
    # Replace default path with system Qt installation folder if necessary
    [string] $QtPath = "C:\Qt",
    [string] $QtInstallPath = "C:\Qt\6.3.2",
    [string] $QtCompile64 = "msvc2019_64",
    # Important:
    # - Do not update ASIO SDK without checking for license-related changes.
    # - Do not copy (parts of) the ASIO SDK into the Jamulus source tree without
    #   further consideration as it would make the license situation more complicated.
    #
    # The following version pinnings are semi-automatically checked for
    # updates. Verify .github/workflows/bump-dependencies.yaml when changing those manually:
    [string] $AsioSDKName = "asiosdk_2.3.3_2019-06-14",
    [string] $AsioSDKUrl = "https://download.steinberg.net/sdk_downloads/asiosdk_2.3.3_2019-06-14.zip",
    [string] $VsDistFile64Path = "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Redist\MSVC\14.32.31326\x64\Microsoft.VC143.CRT",
    [string] $BuildOption = ""
)

# Fail early on all errors
$ErrorActionPreference = "Stop"

# change directory to the directory above (if needed)
Set-Location -Path "$PSScriptRoot\..\"

# Global constants
$RootPath = "$PWD"
$BuildPath = "$RootPath\build"
$DeployPath = "$RootPath\deploy"
$WindowsPath ="$RootPath\windows"
$AppName = "Koord"

# Stop at all errors
$ErrorActionPreference = "Stop"

# Execute native command with errorlevel handling
Function Invoke-Native-Command {
    param(
        [string] $Command,
        [string[]] $Arguments
    )

    & "$Command" @Arguments

    if ($LastExitCode -Ne 0)
    {
        Throw "Native command $Command returned with exit code $LastExitCode"
    }
}

# Cleanup existing build folders
Function Clean-Build-Environment
{
    if (Test-Path -Path $BuildPath) { Remove-Item -Path $BuildPath -Recurse -Force }
    if (Test-Path -Path $DeployPath) { Remove-Item -Path $DeployPath -Recurse -Force }

    New-Item -Path $BuildPath -ItemType Directory
    New-Item -Path $DeployPath -ItemType Directory
}


function Initialize-Module-Here ($m) { # see https://stackoverflow.com/a/51692402

    # If module is imported say that and do nothing
    if (Get-Module | Where-Object {$_.Name -eq $m}) {
        Write-Output "Module $m is already imported."
    }
    else {

        # If module is not imported, but available on disk then import
        if (Get-Module -ListAvailable | Where-Object {$_.Name -eq $m}) {
            Import-Module $m
        }
        else {

            # If module is not imported, not available on disk, but is in online gallery then install and import
            if (Find-Module -Name $m | Where-Object {$_.Name -eq $m}) {
                Install-Module -Name $m -Force -Verbose -Scope CurrentUser
                Import-Module $m
            }
            else {

                # If module is not imported, not available and not in online gallery then abort
                Write-Output "Module $m not imported, not available and not in online gallery, exiting."
                EXIT 1
            }
        }
    }
}

# Download and uncompress dependency in ZIP format
Function Install-Dependency
{
    param(
        [Parameter(Mandatory=$true)]
        [string] $Uri,
        [Parameter(Mandatory=$true)]
        [string] $Name,
        [Parameter(Mandatory=$true)]
        [string] $Destination
    )

    if (Test-Path -Path "$WindowsPath\$Destination")
    {
        echo "Using ${WindowsPath}\${Destination} from previous run (e.g. actions/cache)"
        return
    }

    $TempFileName = [System.IO.Path]::GetTempFileName() + ".zip"
    $TempDir = [System.IO.Path]::GetTempPath()

    Invoke-WebRequest -Uri $Uri -OutFile $TempFileName
    echo $TempFileName
    Expand-Archive -Path $TempFileName -DestinationPath $TempDir -Force
    echo $WindowsPath\$Destination
    Move-Item -Path "$TempDir\$Name" -Destination "$WindowsPath\$Destination" -Force
    Remove-Item -Path $TempFileName -Force
}

# Install VSSetup (Visual Studio detection), ASIO SDK
Function Install-Dependencies
{
    if (-not (Get-PackageProvider -Name nuget).Name -eq "nuget") {
      Install-PackageProvider -Name "Nuget" -Scope CurrentUser -Force
    }
    Initialize-Module-Here -m "VSSetup"
    Install-Dependency -Uri $AsioSDKUrl `
        -Name $AsioSDKName -Destination "ASIOSDK2"
    
}

# Setup environment variables and build tool paths
Function Initialize-Build-Environment
{
    param(
        [Parameter(Mandatory=$true)]
        [string] $BuildArch
    )

    # Look for Visual Studio/Build Tools 2017 or later (version 15.0 or above)
    $VsInstallPath = Get-VSSetupInstance | `
        Select-VSSetupInstance -Product "*" -Version "17.0" -Latest | `
        Select-Object -ExpandProperty "InstallationPath"

    if ($VsInstallPath -Eq "") { $VsInstallPath = "<N/A>" }

    $VcVarsBin = "$VsInstallPath\VC\Auxiliary\build\vcvars64.bat"

    # # Setup Qt executables paths for later calls
    # Set-Item Env:QtQmakePath "$QtMsvcSpecPath\qmake.exe"
    # Set-Item Env:QtCmakePath  "C:\Qt\Tools\CMake_64\bin\cmake.exe" #FIXME should use $Env:QtPath
    # Set-Item Env:QtWinDeployPath "$QtMsvcSpecPath\windeployqt.exe"

    ""
    "**********************************************************************"
    "Using Visual Studio/Build Tools environment settings located at"
    $VcVarsBin
    "**********************************************************************"
    ""

    if (-Not (Test-Path -Path $VcVarsBin))
    {
        Throw "Microsoft Visual Studio ($BuildArch variant) is not installed. " + `
            "Please install Visual Studio 2017 or above it before running this script."
    }

    # Import environment variables set by vcvarsXX.bat into current scope
    $EnvDump = [System.IO.Path]::GetTempFileName()
    Invoke-Native-Command -Command "cmd" `
        -Arguments ("/c", "`"$VcVarsBin`" && set > `"$EnvDump`"")

    foreach ($_ in Get-Content -Path $EnvDump)
    {
        if ($_ -Match "^([^=]+)=(.*)$")
        {
            Set-Item "Env:$($Matches[1])" $Matches[2]
        }
    }

    Remove-Item -Path $EnvDump -Force
}

# Setup Qt environment variables and build tool paths
Function Initialize-Qt-Build-Environment
{
    param(
        [Parameter(Mandatory=$true)]
        [string] $QtInstallPath,
        [Parameter(Mandatory=$true)]
        [string] $QtCompile
    )

    $QtMsvcSpecPath = "$QtInstallPath\$QtCompile\bin"

    # Setup Qt executables paths for later calls
    Set-Item Env:QtQmakePath "$QtMsvcSpecPath\qmake.exe"
    Set-Item Env:QtCmakePath  "C:\Qt\Tools\CMake_64\bin\cmake.exe" #FIXME should use $Env:QtPath
    Set-Item Env:QtWinDeployPath "$QtMsvcSpecPath\windeployqt.exe"

    "**********************************************************************"
    "Using Qt binaries for Visual C++ located at"
    $QtMsvcSpecPath
    "**********************************************************************"
    ""

    if (-Not (Test-Path -Path $Env:QtQmakePath))
    {
        Throw "The Qt binaries for Microsoft Visual C++ 2017 or above could not be located at $QtMsvcSpecPath. " + `
            "Please install Qt with support for MSVC 2017 or above before running this script," + `
            "then call this script with the Qt install location, for example C:\Qt\6.3.1"
    }
}

# Build app for x86_64
Function BuildApp
{
    param(
        [Parameter(Mandatory=$true)]
        [string] $BuildConfig,
        [Parameter(Mandatory=$true)]
        [string] $BuildArch
    )
    # $BuildConfig = "release"
    # $BuildArch = "x86_64"

    ###################################
    ## Build KOORDASIOCONFIG
    ###################################
    Invoke-Native-Command -Command "$Env:QtCmakePath" `
        -Arguments ("-DCMAKE_PREFIX_PATH='$QtInstallPath\$QtCompile64\lib\cmake'", `
            "-DCMAKE_BUILD_TYPE=Release", `
            "-S", "$RootPath\KoordASIO\src\kdasioconfig", `
            "-B", "$BuildPath\$BuildConfig\kdasioconfig", `
            "-G", "NMake Makefiles")
    Set-Location -Path "$BuildPath\$BuildConfig\kdasioconfig"
    Invoke-Native-Command -Command "nmake" #FIXME necessary??

    ###################################
    ## Build KoordASIO dlls ... again ? Previously done in autobuild
    ###################################
    Set-Location -Path "$RootPath"
    # Ninja! 
    Invoke-Native-Command -Command "$Env:QtCmakePath" `
        -Arguments ("-S", "$RootPath\KoordASIO\src", `
            "-B", "$BuildPath\$BuildConfig\flexasio", `
            "-G", "Ninja", `
            "-DCMAKE_BUILD_TYPE=Release")
    # Build!
    Invoke-Native-Command -Command "$Env:QtCmakePath" `
        -Arguments ("--build", "$BuildPath\$BuildConfig\flexasio")

    ###################################
    ## Build Koord app complete
    ###################################
    Invoke-Native-Command -Command "$Env:QtQmakePath" `
        -Arguments ("$RootPath\$AppName.pro", "CONFIG+=$BuildConfig $BuildArch $BuildOption", `
        "-o", "$BuildPath\Makefile")

    # Compile
    Set-Location -Path $BuildPath
    if (Get-Command "jom.exe" -ErrorAction SilentlyContinue)
    {
        echo "Building with jom /J ${Env:NUMBER_OF_PROCESSORS}"
        Invoke-Native-Command -Command "jom" -Arguments ("/J", "${Env:NUMBER_OF_PROCESSORS}", "$BuildConfig")
    }
    else
    {
        echo "Building with nmake (install Qt jom if you want parallel builds)"
        Invoke-Native-Command -Command "nmake" -Arguments ("$BuildConfig")
    }
    Invoke-Native-Command -Command "$Env:QtWinDeployPath" `
        -Arguments ("--$BuildConfig", "--no-compiler-runtime", "--dir=$DeployPath\$BuildArch", `
        "--no-system-d3d-compiler",  "--no-opengl-sw", `
        "$BuildPath\$BuildConfig\kdasioconfig\KoordASIOControl.exe")
    
    ## Run windeployqt for Koord.exe
    Invoke-Native-Command -Command "$Env:QtWinDeployPath" `
        -Arguments ("--$BuildConfig", "--no-compiler-runtime", "--dir=$DeployPath\$BuildArch", `
        "--no-system-d3d-compiler", "--qmldir=$RootPath\src", `
        "-webenginecore", "-webenginewidgets", "-webview", "-qml", "-quick", `
        "$BuildPath\$BuildConfig\$AppName.exe")

    ###################################
    ## Build Application Dir structure 
    ################################### 
    Move-Item -Path "$BuildPath\$BuildConfig\$AppName.exe" -Destination "$DeployPath\$BuildArch" -Force
    # get visibility on deployed files
    Tree "$DeployPath\$BuildArch" /f /a
    # Manually copy in webengine exe
    Copy-Item -Path "$QtInstallPath/$QtCompile64/bin/QtWebEngineProcess.exe" -Destination "$DeployPath\$BuildArch"
    # Transfer VS dist DLLs for x64
    Copy-Item -Path "$VsDistFile64Path\*" -Destination "$DeployPath\$BuildArch"
        # Also add KoordASIO build files:
            # kdasioconfig files inc qt dlls now in 
                # D:/a/KoordASIO/KoordASIO/deploy/x86_64/
                    # - KoordASIOControl.exe
                    # all qt dlls etc ...
            # flexasio files in:
                # D:\a\KoordASIO\KoordASIO\src\out\install\x64-Release\bin
                    # - KoordASIO.dll
                    # - portaudio.dll 
    # Move KoordASIOControl.exe to deploy dir
    Move-Item -Path "$BuildPath\$BuildConfig\kdasioconfig\KoordASIOControl.exe" -Destination "$DeployPath\$BuildArch" -Force
    # Move all KoordASIO dlls and exes to deploy dir
    Move-Item -Path "$RootPath\KoordASIO\src\out\install\x64-Release\bin\ASIOTest.dll" -Destination "$DeployPath\$BuildArch" -Force
    Move-Item -Path "$RootPath\KoordASIO\src\out\install\x64-Release\bin\FlexASIOTest.exe" -Destination "$DeployPath\$BuildArch" -Force
    Move-Item -Path "$RootPath\KoordASIO\src\out\install\x64-Release\bin\KoordASIO.dll" -Destination "$DeployPath\$BuildArch" -Force
    Move-Item -Path "$RootPath\KoordASIO\src\out\install\x64-Release\bin\portaudio.dll" -Destination "$DeployPath\$BuildArch" -Force
    Move-Item -Path "$RootPath\KoordASIO\src\out\install\x64-Release\bin\PortAudioDevices.exe" -Destination "$DeployPath\$BuildArch" -Force
    Move-Item -Path "$RootPath\KoordASIO\src\out\install\x64-Release\bin\sndfile.dll" -Destination "$DeployPath\$BuildArch" -Force
    # move InnoSetup script to deploy dir
    Move-Item -Path "$WindowsPath\kdinstaller.iss" -Destination "$RootPath" -Force

    # clean up
    Invoke-Native-Command -Command "nmake" -Arguments ("clean")
    Set-Location -Path $RootPath
}

# Build and deploy Koord 64bit
function BuildAppVariants
{
    Initialize-Build-Environment -BuildArch "x86_64"
    Initialize-Qt-Build-Environment -QtInstallPath $QtInstallPath -QtCompile $QtCompile64
    BuildApp -BuildConfig "release" -BuildArch "x86_64"
}

# Build Windows installer
Function BuildInstaller
{
    # unused for now
    param(
        [string] $BuildOption
    )

    $AppVersion = $Env:KOORD_BUILD_VERSION

    Set-Location -Path "$RootPath"

    Invoke-Native-Command -Command "iscc" `
        -Arguments ("$RootPath\kdinstaller.iss", `
         "/FKoord-${AppVersion}", `
         "/DApplicationVersion=${AppVersion}")
}

# Build MSIX / MSIX Package
Function BuildMsixPackage
{

    # make sure we have valid app package manifest file named AppxManifest.xml in the content dir
    Copy-Item -Path "${WindowsPath}\AppxManifest.xml" -Destination "${DeployPath}\x86_64\"
    # copy in images
    Copy-Item -Path "${RootPath}\src\res\main-ico-1024.png" -Destination "${DeployPath}\x86_64\mainicon.png"
    Copy-Item -Path "${RootPath}\windows\StoreAssets\*" -Destination "${DeployPath}\x86_64\"

    Invoke-Native-Command -Command "MakeAppx" `
        -Arguments ("pack", "/nv", "/d", "${DeployPath}\x86_64\", `
        "/p", "${DeployPath}\Koord.msix")

    ## Make app package upload
    # mkdir bundle
    # cp Koord.msix bundle/
    # cd bundle
    # zip * somearchivename.zip
    # mv somearchivename.zip somearchivename.msixupload

}

Function SignExe
{
    $WindowsOVCertPwd = Get-Content "C:\KoordOVCertPwd" 

    Invoke-Native-Command -Command "SignTool" `
        -Arguments ("sign", "/f", "C:\KoordOVCert.pfx", `
        "/p", $WindowsOVCertPwd, `
        "/tr", "http://timestamp.sectigo.com", `
        "/td", "SHA256", "/fd", "SHA256", `
        "Output\Koord-$APP_BUILD_VERSION.exe" )
}

# Function SignMsix
# {
#     Invoke-Native-Command -Command "SignTool" `
#         -Arguments ("sign", "/a", "/f", "C:\KoordOVCert.pfx", `
#         "/p", "passwordhere", `
#         "/fd", "SHA256", `
#         "${DeployPath}\Koord.msix")
# }

Clean-Build-Environment
Install-Dependencies
BuildAppVariants
BuildInstaller -BuildOption $BuildOption
SignExe
BuildMsixPackage
#SignMsix