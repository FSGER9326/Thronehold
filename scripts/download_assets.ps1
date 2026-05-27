<#
.SYNOPSIS
    Downloads free CC0 pixel art assets for Thronehold from various sources.
.DESCRIPTION
    Creates required directory structure and downloads (or prints instructions for)
    free CC0/CC-BY assets including UI borders, icons, fonts, and sound effects.
    Safe to run multiple times -- existing files are not re-downloaded.
#>

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot

# ---- Asset manifest --------------------------------------------------------

$Assets = @(

    @{
        Name        = "Kenney Fantasy UI Borders"
        License     = "CC0"
        URL         = "https://kenney.nl/assets/fantasy-ui-borders"
        DownloadURL = "https://kenney.nl/media/pages/assets/fantasy-ui-borders/ab29cd0165-1701602367/kenney_fantasy-ui-borders.zip"
        TargetDir   = "assets/ui/kenney"
        IsDirect    = $true
        Description = "130+ fantasy-themed UI border sprites (panels, buttons, windows)"
        Attribution = "Kenney (www.kenney.nl)"
    }

    @{
        Name        = "Ravenmore Strategy Resource Icons"
        License     = "CC0"
        URL         = "https://ravenmore.itch.io/strategy-game-resource-icons"
        DownloadURL = "https://ravenmore.itch.io/strategy-game-resource-icons"
        TargetDir   = "assets/icons/resources"
        IsDirect    = $false
        Description = "86 strategy game resource icons (gold, food, wood, stone, etc.)"
        Attribution = "None required"
    }

    @{
        Name        = "BoldPixels Font"
        License     = "CC0"
        URL         = "https://yukipixels.itch.io/boldpixels"
        DownloadURL = "https://yukipixels.itch.io/boldpixels"
        TargetDir   = "assets/fonts"
        IsDirect    = $false
        Description = "Pixel art bitmap font family in multiple sizes"
        Attribution = "None required"
    }

    @{
        Name        = "Gothic Pixel UI"
        License     = "CC0"
        URL         = "https://abyssowl.itch.io/gothic-pixel-ui"
        DownloadURL = "https://abyssowl.itch.io/gothic-pixel-ui"
        TargetDir   = "assets/ui/gothic"
        IsDirect    = $false
        Description = "Gothic-themed pixel UI elements (frames, buttons, panels)"
        Attribution = "None required"
    }

    @{
        Name        = "Interface SFX Pack 1"
        License     = "CC0"
        URL         = "https://obsydianx.itch.io/interface-sfx-pack-1"
        DownloadURL = "https://obsydianx.itch.io/interface-sfx-pack-1"
        TargetDir   = "assets/audio/sfx"
        IsDirect    = $false
        Description = "200+ UI sound effects (clicks, hovers, notifications, swishes)"
        Attribution = "None required"
    }

)

# ---- Helper functions ------------------------------------------------------

function Write-Step {
    param([string]$Text)
    Write-Host "`n==> $Text" -ForegroundColor Cyan
}

function Write-OK {
    param([string]$Text)
    Write-Host "    [OK] $Text" -ForegroundColor Green
}

function Write-Skip {
    param([string]$Text)
    Write-Host "    [/] $Text" -ForegroundColor Yellow
}

function Write-Info {
    param([string]$Text)
    Write-Host "    [i] $Text" -ForegroundColor DarkGray
}

function Ensure-Directory {
    param([string]$Path)
    $fullPath = Join-Path $ProjectRoot $Path
    if (-not (Test-Path $fullPath)) {
        New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
        Write-OK "Created directory: $Path"
    } else {
        Write-Skip "Directory exists: $Path"
    }
}

function Ensure-GitKeep {
    param([string]$Path)
    $fullPath = Join-Path $ProjectRoot $Path
    $gitkeep = Join-Path $fullPath ".gitkeep"
    if (-not (Test-Path $gitkeep)) {
        "" | Out-File -FilePath $gitkeep -Encoding ASCII
        Write-OK "Created .gitkeep in $Path"
    } else {
        Write-Skip ".gitkeep exists in $Path"
    }
}

function Download-Asset {
    param(
        [string]$Name,
        [string]$Url,
        [string]$TargetDir,
        [string]$ZipName
    )
    $fullDir = Join-Path $ProjectRoot $TargetDir
    $zipPath = Join-Path $fullDir $ZipName

    if (Test-Path $zipPath) {
        Write-Skip "Already downloaded: $ZipName"
        return
    }

    Write-Info "Downloading $ZipName ..."
    try {
        Invoke-WebRequest -Uri $Url -OutFile $zipPath -UseBasicParsing -ErrorAction Stop
        Write-OK "Downloaded $ZipName ($([math]::Round((Get-Item $zipPath).Length / 1KB)) KB)"
    }
    catch {
        Write-Host "    [!!] Download failed: $_" -ForegroundColor Red
        if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
    }
}

# ---- Main ------------------------------------------------------------------

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "     Thronehold -- Asset Downloader" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

$autoDownloaded = @()
$manualDownload = @()

foreach ($asset in $Assets) {

    Write-Step $asset.Name

    # 1. Ensure target directory exists
    Ensure-Directory $asset.TargetDir

    if ($asset.IsDirect) {
        # -- Direct download --------------------------------------------------
        $zipName = "$($asset.Name -replace ' ', '_').zip"
        Download-Asset -Name $asset.Name -Url $asset.DownloadURL -TargetDir $asset.TargetDir -ZipName $zipName

        # Extract if ZIP was newly downloaded
        $fullDir = Join-Path $ProjectRoot $asset.TargetDir
        $zipPath = Join-Path $fullDir $zipName
        $extractMarker = Join-Path $fullDir ".extracted_$($asset.Name.Replace(' ','_'))"
        if ((Test-Path $zipPath) -and -not (Test-Path $extractMarker)) {
            Write-Info "Extracting ZIP to $($asset.TargetDir) ..."
            try {
                Expand-Archive -Path $zipPath -DestinationPath $fullDir -Force
                # Mark as extracted
                "" | Out-File -FilePath $extractMarker -Encoding ASCII
                Write-OK "Extraction complete"
            }
            catch {
                Write-Host "    [!!] Extraction failed: $_" -ForegroundColor Red
            }
        } elseif (Test-Path $zipPath) {
            Write-Skip "Already extracted (marker found)"
        }

        $autoDownloaded += $asset.Name
    } else {
        # -- Manual download (itch.io) ---------------------------------------
        Write-Info "No direct download URL available."
        Write-Info "Please download manually from:"
        Write-Host "       $($asset.URL)" -ForegroundColor White
        Write-Info "Then extract the contents into: $($asset.TargetDir)"
        Write-Info ""

        $manualDownload += @{ Name = $asset.Name; URL = $asset.URL; Target = $asset.TargetDir }
    }

    # 2. Ensure .gitkeep exists
    Ensure-GitKeep $asset.TargetDir
}

# -- Create parent directories that might not exist --------------------------

$extraDirs = @(
    "assets/ui",
    "assets/icons",
    "assets/fonts",
    "assets/audio"
)

foreach ($dir in $extraDirs) {
    $fullDir = Join-Path $ProjectRoot $dir
    if (-not (Test-Path $fullDir)) {
        Ensure-Directory $dir
        Ensure-GitKeep $dir
    }
}

# -- Summary -----------------------------------------------------------------

Write-Host "`n====================================================" -ForegroundColor Cyan
Write-Host "                     Summary" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

if ($autoDownloaded.Count -gt 0) {
    Write-Host "`n[OK] Auto-downloaded:" -ForegroundColor Green
    foreach ($name in $autoDownloaded) {
        Write-Host "     - $name" -ForegroundColor Green
    }
}

if ($manualDownload.Count -gt 0) {
    Write-Host "`n[!] Manual download required:" -ForegroundColor Yellow
    foreach ($item in $manualDownload) {
        Write-Host "     - $($item.Name)" -ForegroundColor Yellow
        Write-Host "       URL : $($item.URL)" -ForegroundColor DarkGray
        Write-Host "       Dir : $($item.Target)" -ForegroundColor DarkGray
    }
    Write-Host "`n    Open each URL above in your browser, download the ZIP," -ForegroundColor Yellow
    Write-Host "    and extract its contents into the listed directory." -ForegroundColor Yellow
}

Write-Host "`nDone. See assets/README.md for full attribution details.`n" -ForegroundColor Cyan
