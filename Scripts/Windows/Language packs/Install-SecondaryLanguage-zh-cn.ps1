#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installs zh-cn (Chinese Simplified) as a SECONDARY display language only.
    en-us remains the primary UI language, system locale, and user locale -
    this script does not touch any of those. It only adds zh-cn to the
    language list and installs its CAB packages.

.DESCRIPTION
    - Auto-detects the OS DisplayVersion (24H2, 25H2, 26H2, etc.), then looks for a build-specific
      CAB folder before falling back to a flat, non-versioned layout:
        <ScriptRoot>\
            24H2\zh-cn\*.cab
            25H2\zh-cn\*.cab
            26H2\zh-cn\*.cab
      If no build-specific folder exists for the detected OS, falls back to
      <ScriptRoot>\zh-cn\*.cab (flat layout).
    - Installs the zh-cn Client Language Pack + Basic + OCR + Handwriting +
      Speech + TextToSpeech CABs found in that folder via DISM.
    - Appends zh-cn to the existing Windows language list as a SECONDARY
      language (en-us / whatever is already first stays first / primary).
      Does NOT call Set-WinSystemLocale, Set-WinUILanguageOverride, or
      Set-Culture - those would change the primary language, which is out
      of scope for this script.
    - Writes an Intune/SCCM detection registry key after a successful install:
        HKLM\SOFTWARE\eskonr\LanguagePack\zh-cn
            Installed      = 1
            InstalledDate  = <install date>
            OSBuild        = <detected OS release, e.g. 24H2>

.PARAMETER LangPackRoot
    Optional explicit path to the folder containing the zh-cn CAB files.
    Overrides auto-detection. If not specified, resolved as
    <ScriptRoot>\<OSBuild>\zh-cn, falling back to <ScriptRoot>\zh-cn.

.PARAMETER RegistryRoot
    Registry root used for the Intune/SCCM detection key.
    Final key is "<RegistryRoot>\zh-cn", e.g. HKLM:\SOFTWARE\eskonr\LanguagePack\zh-cn

.EXAMPLE
    .\Install-SecondaryLanguage-zh-cn.ps1
    Auto-detects OS build, finds the matching zh-cn CAB folder, installs it,
    adds zh-cn as a secondary language, and writes the detection key.

.EXAMPLE
    .\Install-SecondaryLanguage-zh-cn.ps1 -LangPackRoot "\\server\share\zh-cn"
    Skips auto-detection and installs directly from the given folder.

.NOTES
    Tested on Windows 11 24H2/25H2/26H2
    Must run as SYSTEM / Administrator in full OS phase
    Works standalone (Intune Win32 app, SCCM application/package, or manual run) -
    no Task Sequence / UI++ dependency, since this is not an OSD-time step.
#>

[CmdletBinding()]
param(
    [string]$LangPackRoot,
    [string]$RegistryRoot = 'HKLM:\SOFTWARE\eskonr\LanguagePack'
)

$SecondaryLang = 'zh-cn'

# =============================================================================
# LOGGING
# =============================================================================
if ($PSCommandPath -ne $null -and $PSCommandPath -ne '') {
    $ScriptRoot = Split-Path -Parent $PSCommandPath
} else {
    $ScriptRoot = (Get-Location).Path
}

$LogFile = if ($env:_SMSTSLogPath) {
    Join-Path $env:_SMSTSLogPath 'Install-SecondaryLanguage-zh-cn.log'
} else {
    'C:\Windows\Temp\Install-SecondaryLanguage-zh-cn.log'
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'OK', 'SKIP')]
        [string]$Level = 'INFO'
    )
    $Line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  [$Level]  $Message"
    $Line | Out-File $LogFile -Append -Encoding UTF8
    Write-Host $Line
}

function Write-LogSeparator {
    param([string]$Title = '')
    $Line = if ($Title) {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  ──── $Title ────"
    } else {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  " + ('─' * 50)
    }
    $Line | Out-File $LogFile -Append -Encoding UTF8
    Write-Host $Line
}

function Invoke-ExeLogged {
    param([string[]]$ArgumentList)
    $exe    = $ArgumentList[0]
    $params = $ArgumentList[1..($ArgumentList.Length - 1)]
    $output = & $exe @params 2>&1
    foreach ($line in $output) {
        $text = $line.ToString().Trim()
        if ($text) { Write-Log "    $text" }
    }
    return $LASTEXITCODE
}

$ScriptStart = Get-Date
Write-LogSeparator 'Install-SecondaryLanguage-zh-cn  START'
Write-Log "Script Root  : $ScriptRoot"
Write-Log "Log file     : $LogFile"

# =============================================================================
# PHASE 1 - Detect OS build and resolve the zh-cn CAB folder
# =============================================================================
Write-LogSeparator 'Phase 1 - Detect OS build and resolve CAB folder'

function Get-OSReleaseLabel {
    try {
        $regPath  = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
        $regProps = Get-ItemProperty $regPath -ErrorAction Stop

        $DisplayVersion = $regProps.DisplayVersion   # Present on Win10/11 and Server 2025
        $ProductName    = $regProps.ProductName      # Present on ALL versions
        $CurrentBuild   = $regProps.CurrentBuild
        $UBR            = $regProps.UBR

        if ($DisplayVersion) {
            # Covers 24H2, 25H2, 26H2, and any future label - no hardcoded list needed
            Write-Log "Detected DisplayVersion: $DisplayVersion (Build $CurrentBuild.$UBR)"
            return $DisplayVersion
        }

        # Windows Server 2019 / 2022 - map by CurrentBuild number
        $label = switch ($CurrentBuild) {
            { $_ -ge 17763 -and $_ -le 17999 } { '2019' }
            { $_ -ge 20348 -and $_ -le 20999 } { '2022' }
            default {
                if ($ProductName -match 'Server\s+(\d{4})') {
                    "Server$($Matches[1])"
                } else {
                    $CurrentBuild
                }
            }
        }
        Write-Log "DisplayVersion not found. Using build-based OS label: $label"
        Write-Log "ProductName: $ProductName | Build: $CurrentBuild.$UBR"
        return $label
    } catch {
        Write-Log "Failed to detect OS version: $($_.Exception.Message)" -Level WARN
        return $null
    }
}

$OSRelease = Get-OSReleaseLabel
Write-Log "OS Release label for folder lookup: $OSRelease"

if ($LangPackRoot) {
    Write-Log "LangPackRoot explicitly specified via parameter: $LangPackRoot"
} else {
    $buildRoot = if ($OSRelease) { Join-Path $ScriptRoot "$OSRelease\$SecondaryLang" } else { $null }
    $flatRoot  = Join-Path $ScriptRoot $SecondaryLang

    if ($buildRoot -and (Test-Path $buildRoot -PathType Container)) {
        $LangPackRoot = $buildRoot
        Write-Log "Auto-detected build-specific CAB folder: $LangPackRoot"
    } elseif (Test-Path $flatRoot -PathType Container) {
        $LangPackRoot = $flatRoot
        Write-Log "No build-specific folder found ($buildRoot) - using flat layout: $LangPackRoot" -Level WARN
    } else {
        $LangPackRoot = if ($buildRoot) { $buildRoot } else { $flatRoot }
        Write-Log "No zh-cn CAB folder found. Expected: $buildRoot or $flatRoot" -Level ERROR
    }
}

if (-not (Test-Path $LangPackRoot)) {
    Write-Log "CAB folder does not exist: $LangPackRoot - cannot continue." -Level ERROR
    exit 1
}

# =============================================================================
# PHASE 2 - Install zh-cn CAB packages via DISM
# =============================================================================
Write-LogSeparator 'Phase 2 - Install zh-cn CAB packages'

$installOrder = @{
    'Client-Language-Pack' = 0
    'Language-Pack'        = 0
    'Basic'                = 1
    'OCR'                  = 2
    'Handwriting'          = 3
    'TextToSpeech'         = 4   # checked before 'Speech' via length sort
    'Speech'               = 5
    'Fonts'                = 6
}

$allCabs = Get-ChildItem -Path $LangPackRoot -Filter '*.cab' -Recurse
if (-not $allCabs) {
    Write-Log "No .cab files found in $LangPackRoot - nothing to install." -Level ERROR
    exit 1
}

$sortedCabs = $allCabs | Sort-Object {
    $priority = 99
    foreach ($key in ($installOrder.Keys | Sort-Object { $_.Length } -Descending)) {
        if ($_.Name -match $key) { $priority = $installOrder[$key]; break }
    }
    $priority
}

Write-Log "$($sortedCabs.Count) CAB(s) found for zh-cn in $LangPackRoot"

$allSucceeded = $true
$rebootPending = $false

foreach ($cab in $sortedCabs) {
    Write-Log "DISM install: $($cab.Name)"
    $exitCode = Invoke-ExeLogged @(
        'dism.exe', '/Online', '/Add-Package',
        "/PackagePath:$($cab.FullName)",
        '/NoRestart', '/Quiet'
    )
    if ($exitCode -eq 0 -or $exitCode -eq 3010) {
        Write-Log "$($cab.Name) installed (DISM exit $exitCode)." -Level OK
        if ($exitCode -eq 3010) {
            $rebootPending = $true
            Write-Log 'Exit 3010 - reboot pending.'
        }
    } else {
        Write-Log "$($cab.Name) FAILED (DISM exit $exitCode). Check C:\Windows\Logs\DISM\dism.log" -Level ERROR
        $allSucceeded = $false
    }
}

if (-not $allSucceeded) {
    Write-Log 'One or more zh-cn CABs failed to install - registry key will not be written.' -Level ERROR
    exit 1
}

# =============================================================================
# PHASE 3 - Add zh-cn to the language list as SECONDARY (append only)
# =============================================================================
Write-LogSeparator 'Phase 3 - Add zh-cn as secondary language'

try {
    $currentList = Get-WinUserLanguageList
    $currentTags = $currentList | ForEach-Object { $_.LanguageTag.ToLower() }
    Write-Log "Current language list: $($currentTags -join ', ')"

    if ($currentTags -contains $SecondaryLang) {
        Write-Log "$SecondaryLang is already in the language list - nothing to append." -Level SKIP
    } else {
        # Append zh-cn to the END of the existing list, so whatever is first
        # today (normally en-us) stays first / primary.
        $currentList.Add($SecondaryLang)
        Set-WinUserLanguageList -LanguageList $currentList -Force
        Write-Log "$SecondaryLang appended as secondary language. New order: $((Get-WinUserLanguageList | ForEach-Object { $_.LanguageTag }) -join ', ')" -Level OK
    }
} catch {
    Write-Log "Failed to update language list: $_" -Level ERROR
    exit 1
}

# Copy to Welcome screen / new user accounts, so the secondary language is
# available system-wide, not just for the currently logged-on user.
try {
    Copy-UserInternationalSettingsToSystem -WelcomeScreen $true -NewUser $true
    Write-Log 'Copy-UserInternationalSettingsToSystem completed.' -Level OK
} catch {
    Write-Log "Copy-UserInternationalSettingsToSystem failed: $_" -Level WARN
}

# =============================================================================
# PHASE 4 - Write Intune/SCCM detection registry key
# =============================================================================
Write-LogSeparator 'Phase 4 - Write detection registry key'

$InstalledDateStamp = Get-Date -Format 'yyyy-MM-dd'
$keyPath = Join-Path $RegistryRoot $SecondaryLang

try {
    if (-not (Test-Path $keyPath)) {
        New-Item -Path $keyPath -Force | Out-Null
    }
    New-ItemProperty -Path $keyPath -Name 'Installed'     -Value '1'                -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $keyPath -Name 'InstalledDate' -Value $InstalledDateStamp -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $keyPath -Name 'OSBuild'       -Value $(if ($OSRelease) { $OSRelease } else { 'Unknown' }) -PropertyType String -Force | Out-Null
    Write-Log "Detection key written: $keyPath (Installed=1, InstalledDate=$InstalledDateStamp, OSBuild=$OSRelease)" -Level OK
} catch {
    Write-Log "Failed to write detection key at $keyPath : $_" -Level ERROR
}

# =============================================================================
# DONE
# =============================================================================
Write-LogSeparator 'Install-SecondaryLanguage-zh-cn  COMPLETE'
$elapsed = New-TimeSpan -Start $ScriptStart -End (Get-Date)
Write-Log "SecondaryLang : $SecondaryLang"
Write-Log "OSBuild       : $OSRelease"
Write-Log "LangPackRoot  : $LangPackRoot"
Write-Log "RegistryRoot  : $RegistryRoot"
Write-Log "Runtime       : $($elapsed.Minutes)m $($elapsed.Seconds)s"
Write-Log "Log saved to  : $LogFile"

if ($rebootPending) {
    Write-Log 'Reboot pending from one or more CAB installs - exiting 3010.' -Level INFO
    exit 3010
}

exit 0
