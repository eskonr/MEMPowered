#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Safe C: Drive Disk Cleanup for Windows Server
    Targets only system-generated temp/cache files. Does NOT touch user data.

.DESCRIPTION
    Cleans the following (safe to remove):
      - Windows Temp folder (%SystemRoot%\Temp)
      - User profile Temp folders (%USERPROFILE%\AppData\Local\Temp for each profile)
      - Windows Update cache (SoftwareDistribution\Download)
      - Delivery Optimization cache
      - CBS (Component-Based Servicing) logs
      - Windows Error Reporting / WER queued reports
      - Prefetch files
      - IIS logs (optional - prompted)
      - Recycle Bin (optional - prompted)
      - Windows old upgrade folder (optional - prompted)

.NOTES
    Run as Administrator.
    Safe for Windows Server 2016 / 2019 / 2022.
    Does NOT delete user documents, desktop, downloads, or profile data.
#>

# ─────────────────────────────────────────────
#  CONFIGURATION
# ─────────────────────────────────────────────
$LogFile     = "C:\Logs\DiskCleanup_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$DryRun      = $false   # Set to $true to simulate without deleting anything

# ─────────────────────────────────────────────
#  LOGGING HELPER
# ─────────────────────────────────────────────
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] [$Level] $Message"
    Write-Host $entry -ForegroundColor $(if ($Level -eq "ERROR") {"Red"} elseif ($Level -eq "WARN") {"Yellow"} else {"Cyan"})
    Add-Content -Path $LogFile -Value $entry -ErrorAction SilentlyContinue
}

# ─────────────────────────────────────────────
#  SIZE HELPER
# ─────────────────────────────────────────────
function Get-FolderSizeGB {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return 0 }
    try {
        $bytes = (Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue |
                  Measure-Object -Property Length -Sum).Sum
        return [math]::Round($bytes / 1GB, 2)
    } catch { return 0 }
}

# ─────────────────────────────────────────────
#  CLEANUP HELPER
# ─────────────────────────────────────────────
function Remove-SafeFolder {
    param(
        [string]$Path,
        [string]$Description,
        [switch]$FilesOnly   # Only delete files, keep root folder structure
    )

    if (-not (Test-Path $Path)) {
        Write-Log "$Description — path not found, skipping: $Path" "WARN"
        return
    }

    $sizeBefore = Get-FolderSizeGB -Path $Path
    Write-Log "Cleaning: $Description ($sizeBefore GB) — $Path"

    if (-not $DryRun) {
        try {
            if ($FilesOnly) {
                Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue |
                    Where-Object { -not $_.PSIsContainer } |
                    Remove-Item -Force -ErrorAction SilentlyContinue
            } else {
                Get-ChildItem -Path $Path -Force -ErrorAction SilentlyContinue |
                    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            }
        } catch {
            Write-Log "Error cleaning $Description`: $_" "ERROR"
        }
    } else {
        Write-Log "[DRY RUN] Would delete contents of: $Path" "WARN"
    }

    $sizeAfter = Get-FolderSizeGB -Path $Path
    $freed = [math]::Round($sizeBefore - $sizeAfter, 2)
    Write-Log "  → Freed: $freed GB (Before: $sizeBefore GB | After: $sizeAfter GB)"
    return $freed
}

# ─────────────────────────────────────────────
#  MAIN
# ─────────────────────────────────────────────
Write-Log "============================================================"
Write-Log "  Safe Disk Cleanup Script — Windows Server"
Write-Log "  Mode: $(if ($DryRun) {'DRY RUN (no files deleted)'} else {'LIVE'})"
Write-Log "============================================================"

# Free space before
$driveBefore = (Get-PSDrive -Name C).Free / 1GB
Write-Log "C: Free space BEFORE: $([math]::Round($driveBefore, 2)) GB"

$totalFreed = 0

# ── 1. Windows System Temp ──────────────────
$totalFreed += Remove-SafeFolder -Path "$env:SystemRoot\Temp" `
    -Description "Windows System Temp" -FilesOnly

# ── 2. Per-User Temp Folders ────────────────
Write-Log "Scanning user profile Temp folders..."
$profileBase = "C:\Users"
Get-ChildItem -Path $profileBase -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    $userTemp = Join-Path $_.FullName "AppData\Local\Temp"
    if (Test-Path $userTemp) {
        $totalFreed += Remove-SafeFolder -Path $userTemp `
            -Description "User Temp [$($_.Name)]" -FilesOnly
    }
}

# ── 3. Windows Update Download Cache ────────
# Safe to delete — Windows re-downloads if needed
$totalFreed += Remove-SafeFolder `
    -Path "C:\Windows\SoftwareDistribution\Download" `
    -Description "Windows Update Download Cache"

# ── 4. Delivery Optimization Cache ──────────
$totalFreed += Remove-SafeFolder `
    -Path "C:\Windows\SoftwareDistribution\DeliveryOptimization" `
    -Description "Delivery Optimization Cache"

# ── 5. CBS Logs ──────────────────────────────
# Component Based Servicing logs — safe to clean
$totalFreed += Remove-SafeFolder `
    -Path "C:\Windows\Logs\CBS" `
    -Description "CBS (Servicing) Logs"

# ── 6. Windows Error Reporting ───────────────
$totalFreed += Remove-SafeFolder `
    -Path "C:\ProgramData\Microsoft\Windows\WER\ReportQueue" `
    -Description "WER Report Queue"

$totalFreed += Remove-SafeFolder `
    -Path "C:\ProgramData\Microsoft\Windows\WER\ReportArchive" `
    -Description "WER Report Archive"

# ── 7. Prefetch ──────────────────────────────
# Windows rebuilds these automatically
$totalFreed += Remove-SafeFolder `
    -Path "C:\Windows\Prefetch" `
    -Description "Prefetch Files" -FilesOnly

# ── 8. Windows Installer Patch Cache (Orphans) ─
# Only removes .msp patch files with no registered product — safe
Write-Log "Checking Windows Installer orphaned patch files..."
$installerPath = "C:\Windows\Installer"
if (Test-Path $installerPath) {
    $mspFiles = Get-ChildItem -Path $installerPath -Filter "*.msp" -Force -ErrorAction SilentlyContinue
    $sizeMsp  = [math]::Round(($mspFiles | Measure-Object Length -Sum).Sum / 1GB, 2)
    Write-Log "  Found $($mspFiles.Count) .msp patch files ($sizeMsp GB) in $installerPath"
    Write-Log "  Note: Run 'PatchCleaner' tool for safe orphaned patch removal (not auto-cleaned here)"
}

# ─────────────────────────────────────────────
#  OPTIONAL CLEANUPS — User Prompted
# ─────────────────────────────────────────────

# ── 9. IIS Logs ──────────────────────────────
$iisLogPath = "C:\inetpub\logs\LogFiles"
if (Test-Path $iisLogPath) {
    $iisSize = Get-FolderSizeGB -Path $iisLogPath
    Write-Log ""
    Write-Log "OPTIONAL: IIS Logs found ($iisSize GB) at $iisLogPath" "WARN"
    $answer = Read-Host "  Delete IIS logs older than 30 days? (Y/N)"
    if ($answer -match "^[Yy]") {
        $cutoff = (Get-Date).AddDays(-30)
        $deleted = 0
        Get-ChildItem -Path $iisLogPath -Recurse -Force -ErrorAction SilentlyContinue |
            Where-Object { -not $_.PSIsContainer -and $_.LastWriteTime -lt $cutoff } |
            ForEach-Object {
                if (-not $DryRun) { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue }
                $deleted++
            }
        Write-Log "  Deleted $deleted IIS log file(s) older than 30 days."
    } else {
        Write-Log "  IIS logs skipped by user."
    }
}

# ── 10. Recycle Bin ──────────────────────────
Write-Log ""
$answer = Read-Host "OPTIONAL: Empty Recycle Bin for all users? (Y/N)"
if ($answer -match "^[Yy]") {
    if (-not $DryRun) {
        try {
            Clear-RecycleBin -Force -ErrorAction SilentlyContinue
            Write-Log "  Recycle Bin emptied."
        } catch {
            Write-Log "  Could not empty Recycle Bin: $_" "WARN"
        }
    } else {
        Write-Log "  [DRY RUN] Would empty Recycle Bin." "WARN"
    }
}

# ── 11. Windows.old (Previous OS Upgrade) ───
if (Test-Path "C:\Windows.old") {
    $oldSize = Get-FolderSizeGB -Path "C:\Windows.old"
    Write-Log ""
    Write-Log "OPTIONAL: C:\Windows.old found ($oldSize GB) — previous OS upgrade folder." "WARN"
    $answer = Read-Host "  Delete Windows.old? This CANNOT be undone (Y/N)"
    if ($answer -match "^[Yy]") {
        Write-Log "  Running DISM to remove Windows.old..."
        if (-not $DryRun) {
            & dism.exe /online /cleanup-image /startcomponentcleanup /resetbase 2>&1 |
                ForEach-Object { Write-Log "  DISM: $_" }
        } else {
            Write-Log "  [DRY RUN] Would run DISM /resetbase to remove Windows.old" "WARN"
        }
    }
}

# ─────────────────────────────────────────────
#  SUMMARY
# ─────────────────────────────────────────────
$driveAfter = (Get-PSDrive -Name C).Free / 1GB
Write-Log ""
Write-Log "============================================================"
Write-Log "  CLEANUP COMPLETE"
Write-Log "  C: Free space BEFORE : $([math]::Round($driveBefore, 2)) GB"
Write-Log "  C: Free space AFTER  : $([math]::Round($driveAfter,  2)) GB"
Write-Log "  Total space recovered: $([math]::Round($driveAfter - $driveBefore, 2)) GB"
Write-Log "  Log saved to         : $LogFile"
Write-Log "============================================================"

if ($DryRun) {
    Write-Host "`n[DRY RUN MODE] No files were actually deleted. Set `$DryRun = `$false to run live." -ForegroundColor Yellow
}