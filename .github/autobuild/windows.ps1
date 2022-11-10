# Steps for generating Windows artifacts via Github Actions
# See README.md in this folder for details.
# See windows/deploy_windows.ps1 for standalone builds.

param(
    [Parameter(Mandatory=$true)]
    [string] $Stage = "",
    # Allow buildoption to be passed for jackonwindows build, leave empty for standard (ASIO) build:
    [string] $BuildOption = "",
    # unused, only required during refactoring as long as not all platforms have been updated:
    [string] $GithubWorkspace =""
)

# Fail early on all errors
$ErrorActionPreference = "Stop"

$QtDir = 'C:\Qt'
$ChocoCacheDir = 'C:\ChocoCache'
$Qt32Version = "6.3.2"
$Qt64Version = "6.3.2"
$AqtinstallVersion = "3.0.1"
#$Msvc32Version = "win32_msvc2019"
$Msvc64Version = "win64_msvc2019_64"
$JomVersion = "1.1.2"

$KoordVersion = $Env:KOORD_BUILD_VERSION
if ( $KoordVersion -notmatch '^\d+\.\d+\.\d+.*' )
{
    throw "Environment variable KOORD_BUILD_VERSION has to be set to a valid version string"
}

Function Install-Qt
{
    param(
        [string] $QtVersion,
        [string] $QtArch
    )
    $Args = (
        "--outputdir", "$QtDir",
        "windows",
        "desktop",
        "$QtVersion",
        "$QtArch",
        "--modules", "qtwebengine", "qtwebview", "qtmultimedia", "qtwebchannel", "qtpositioning",
        "--archives", "qtbase", "qtdeclarative", "qtsvg", "qttools"
    )
    aqt install-qt @Args
    if ( !$? )
    {
        echo "WARNING: Qt installation via first aqt run failed, re-starting with different base URL."
        aqt install-qt -b https://mirrors.ocf.berkeley.edu/qt/ @Args
        if ( !$? )
        {
            throw "Qt installation with args @Args failed with exit code $LastExitCode"
        }
    }

    # Above should do:
    # aqt install --outputdir C:\Qt 5.15.2 windows desktop win64_msvc2019_64

    # add vcredist and cmake - for Koord build
    aqt install-tool windows desktop --outputdir C:\Qt tools_vcredist qt.tools.vcredist_msvc2019_x64
    aqt install-tool windows desktop --outputdir C:\Qt tools_cmake qt.tools.cmake
}

Function Ensure-Qt
{
    if ( Test-Path -Path $QtDir )
    {
        echo "Using Qt installation from previous run (actions/cache)"
        return
    }

    echo "Install Qt..."
    # Install Qt
    #   "Preparing metadata (pyproject.toml) did not run successfully."
    pip install "aqtinstall==$AqtinstallVersion" 
    if ( !$? )
    {
        throw "pip install aqtinstall failed with exit code $LastExitCode"
    }

    echo "Get Qt 64 bit..."
    Install-Qt "${Qt64Version}" "${Msvc64Version}"

    # Enough with 32bit !!!
    # echo "Get Qt 32 bit..."
    # Install-Qt "${Qt32Version}" "${Msvc32Version}"
}

Function Ensure-jom
{
    choco install --no-progress -y jom --version "${JomVersion}"
}

Function Build-App-With-Installer
{
    echo "Build app and create installer..."
    $ExtraArgs = @()
    if ( $BuildOption -ne "" )
    {
        $ExtraArgs += ("-BuildOption", $BuildOption)
    }
    powershell ".\windows\deploy_windows.ps1" "C:\Qt\${Qt32Version}" "C:\Qt\${Qt64Version}" @ExtraArgs
    if ( !$? )
    {
        throw "deploy_windows.ps1 failed with exit code $LastExitCode"
    }
}

Function Pass-EXE-Artifact-to-Job
{
    $artifact = "Koord_${KoordVersion}.exe"

    echo "Copying artifact to ${artifact}"
    # "Output" is name of dir for innosetup output
    move ".\Output\Koord*.exe" ".\deploy\${artifact}"
    if ( !$? )
    {
        throw "move failed with exit code $LastExitCode"
    }
    echo "Setting Github step output name=artifact_1::${artifact}"
    echo "artifact_1=${artifact}" >> "$Env:GITHUB_OUTPUT"
}

Function Pass-MSIX-Artifact-to-Job
{
    $artifact = "Koord_${KoordVersion}.msix"

    echo "Copying artifact to ${artifact}"
    # "deploy" is dir of MakeAppx output

    # make special dir for store upload
    New-Item -Path  ".\publish" -ItemType Directory
    # copy .msix artifact to publish/ dir
    copy ".\deploy\Koord.msix" ".\publish\${artifact}"

    move ".\deploy\Koord.msix" ".\deploy\${artifact}"
    if ( !$? )
    {
        throw "move failed with exit code $LastExitCode"
    }
    echo "Setting Github step output name=artifact_2::${artifact}"
    echo "artifact_2=${artifact}" >> "$Env:GITHUB_OUTPUT"
}

switch ( $Stage )
{
    "setup"
    {
        choco config set cacheLocation $ChocoCacheDir
        Ensure-Qt
        Ensure-jom
    }
    "build"
    {
        Build-App-With-Installer
    }
    "get-artifacts"
    {
        Pass-EXE-Artifact-to-Job
        Pass-MSIX-Artifact-to-Job
    }
    default
    {
        throw "Unknown stage ${Stage}"
    }
}
