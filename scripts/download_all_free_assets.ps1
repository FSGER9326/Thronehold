<#
.SYNOPSIS
  Thronehold - Mass Download of Free CC0/CC-BY Game Assets
.DESCRIPTION
  Downloads and extracts a comprehensive collection of FREE pixel art assets
  for the Thronehold strategy game. All assets are CC0 (Public Domain) or
  CC-BY (attribution required). The entire repo becomes self-contained with
  visual assets that any AI (ChatGPT, Claude, etc.) can reference.

  Kenney assets are scraped from kenney.nl to extract download URLs dynamically.
  Other assets (OpenGameArt, Itch.io) include README instructions.

  Usage:
    .\scripts\download_all_free_assets.ps1

  Output structure:
    assets/
    +-- free_packs/
    |   +-- kenney_pixel-platformer/       (tiles)
    |   +-- kenney_roguelike-rpg-pack/     (items, characters)
    |   +-- kenney_ui-pack/                (UI elements)
    |   +-- kenney_interface-sounds/       (SFX)
    |   +-- kenney_input-prompts-pixel/    (input glyphs)
    |   +-- kenney_game-icons/             (icons)
    |   +-- kenney_cursor-pixel-pack/      (cursors)
    |   +-- kenney_fantasy-ui-borders/     (borders)
    |   +-- kenney_kenney-fonts/           (fonts)
    |   +-- kenney_rpg-audio/              (RPG sounds)
    |   +-- kenney_music-jingles/          (jingles)
    |   +-- oga_16x16-fantasy-tileset/     (manual)
    |   +-- ravenmore_strategy-resource-icons/ (manual)
    |   +-- googlefonts_press-start-2p/    (manual)
    +-- ui/kenney/                         (existing Fantasy UI Borders)
    +-- README.md                          (updated asset index)

  License: All assets are CC0 unless noted otherwise.
#>

#Requires -Version 5.0

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# --- Configuration ----------------------------------------------------------
$BaseDir    = Resolve-Path "."
$AssetDir   = Join-Path $BaseDir "assets"
$FreeDir    = Join-Path $AssetDir "free_packs"
$KenneyDir  = Join-Path (Join-Path $AssetDir "ui") "kenney"

# URLs and metadata for each pack
# Using scraped download URLs from kenney.nl - script extracts dynamically from HTML
$KenneyPacks = @(
    @{
        Name     = "pixel-platformer"
        Url      = "https://kenney.nl/assets/pixel-platformer"
        Label    = "Kenney Pixel Platformer (tiles)"
        Dir      = "kenney_pixel-platformer"
        Category = "Terrain and Tilesets"
        Desc     = "200+ 18x18 platformer terrain tiles: grass, dirt, stone, water, lava, bridges, ladders, and more"
        License  = "CC0"
    },
    @{
        Name     = "roguelike-rpg-pack"
        Url      = "https://kenney.nl/assets/roguelike-rpg-pack"
        Label    = "Kenney Roguelike/RPG Pack"
        Dir      = "kenney_roguelike-rpg-pack"
        Category = "Terrain and Tilesets"
        Desc     = "1700+ 16x16 RPG sprites: characters, items, furniture, dungeon walls, floors, doors, chests, weapons"
        License  = "CC0"
    },
    @{
        Name     = "ui-pack"
        Url      = "https://kenney.nl/assets/ui-pack"
        Label    = "Kenney UI Pack"
        Dir      = "kenney_ui-pack"
        Category = "UI Assets"
        Desc     = "430+ UI elements: buttons, panels, sliders, checkboxes, text inputs, scrollbars (v2.0, remade)"
        License  = "CC0"
    },
    @{
        Name     = "interface-sounds"
        Url      = "https://kenney.nl/assets/interface-sounds"
        Label    = "Kenney Interface Sounds"
        Dir      = "kenney_interface-sounds"
        Category = "Audio"
        Desc     = "100+ interface sound effects: clicks, hovers, confirms, cancels, notifications, swishes"
        License  = "CC0"
    },
    @{
        Name     = "input-prompts-pixel"
        Url      = "https://kenney.nl/assets/input-prompts-pixel"
        Label    = "Kenney Input Prompts Pixel"
        Dir      = "kenney_input-prompts-pixel"
        Category = "UI Assets"
        Desc     = "800+ 16x16 input glyphs: keyboard, mouse, Xbox, PlayStation, Nintendo, Steam Deck, arcade, touch"
        License  = "CC0"
    },
    @{
        Name     = "game-icons"
        Url      = "https://kenney.nl/assets/game-icons"
        Label    = "Kenney Game Icons"
        Dir      = "kenney_game-icons"
        Category = "Icons and Resources"
        Desc     = "105 game-related icons: gamepad, joystick, prompts, controller layouts, interface symbols"
        License  = "CC0"
    },
    @{
        Name     = "cursor-pixel-pack"
        Url      = "https://kenney.nl/assets/cursor-pixel-pack"
        Label    = "Kenney Cursor Pixel Pack"
        Dir      = "kenney_cursor-pixel-pack"
        Category = "Icons and Resources"
        Desc     = "180+ 16x16 pixel cursors: various arrow styles, pointers, hand cursors, click indicators"
        License  = "CC0"
    },
    @{
        Name     = "fantasy-ui-borders"
        Url      = "https://kenney.nl/assets/fantasy-ui-borders"
        Label    = "Kenney Fantasy UI Borders"
        Dir      = "kenney_fantasy-ui-borders"
        Category = "UI Assets"
        Desc     = "130+ fantasy-themed UI borders, panels, buttons, windows, decorative frames"
        License  = "CC0"
    },
    @{
        Name     = "kenney-fonts"
        Url      = "https://kenney.nl/assets/kenney-fonts"
        Label    = "Kenney Fonts"
        Dir      = "kenney_kenney-fonts"
        Category = "Fonts"
        Desc     = "11 pixel/bitmap font families: various sizes and styles, perfect for retro games"
        License  = "CC0"
    },
    @{
        Name     = "rpg-audio"
        Url      = "https://kenney.nl/assets/rpg-audio"
        Label    = "Kenney RPG Audio"
        Dir      = "kenney_rpg-audio"
        Category = "Audio"
        Desc     = "50+ RPG sound effects: footsteps, weapons, foley, magic spells, ambient sounds"
        License  = "CC0"
    },
    @{
        Name     = "music-jingles"
        Url      = "https://kenney.nl/assets/music-jingles"
        Label    = "Kenney Music Jingles"
        Dir      = "kenney_music-jingles"
        Category = "Audio"
        Desc     = "85+ short music jingles and stings: fanfares, tension builders, victory themes, sad moments"
        License  = "CC0"
    }
)

$ManualPacks = @(
    @{
        Name     = "oga-16x16-fantasy-tileset"
        Label    = "16x16 Fantasy Tileset (Jerom)"
        Url      = "https://opengameart.org/content/16x16-fantasy-tileset"
        Dir      = "oga_16x16-fantasy-tileset"
        Category = "Terrain and Tilesets"
        Desc     = "Retro 16x16 pixel art tileset with characters, items, monsters, terrain - gameboy-style palette"
        License  = "CC-BY-SA 3.0"
        Note     = "Requires attribution: 'Jerom' + link to OGA page"
        DownloadPage = "https://opengameart.org/content/16x16-fantasy-tileset"
        DownloadNote = "Scroll down to the File(s) section, click the PNG link to download."
    },
    @{
        Name     = "ravenmore-strategy-resource-icons"
        Label    = "Ravenmore Strategy Resource Icons"
        Url      = "https://ravenmore.itch.io/strategy-game-resource-icons"
        Dir      = "ravenmore_strategy-resource-icons"
        Category = "Icons and Resources"
        Desc     = "86 strategy game resource icons: gold, food, wood, stone, gems, books, population, and more"
        License  = "CC0"
        Note     = "No attribution required."
        DownloadPage = "https://ravenmore.itch.io/strategy-game-resource-icons"
        DownloadNote = "itch.io requires manual download: visit URL, click Download Now (set price to $0)."
    },
    @{
        Name     = "press-start-2p"
        Label    = "Press Start 2P - Google Fonts"
        Url      = "https://fonts.google.com/specimen/Press+Start+2P"
        Dir      = "googlefonts_press-start-2p"
        Category = "Fonts"
        Desc     = "Popular pixel/retro font from Google Fonts. Already in assets/fonts/ if installed."
        License  = "OFL (Open Font License)"
        Note     = "SIL Open Font License 1.1 - free for commercial use."
        DownloadPage = "https://fonts.google.com/specimen/Press+Start+2P"
        DownloadNote = "Visit the URL and click 'Download family' to get the .ttf files."
    }
)

# --- Helper Functions -------------------------------------------------------

function Write-Step {
    param([string]$Text, [string]$Color = "Cyan")
    Write-Host "`n=== $Text ===" -ForegroundColor $Color
}

function Write-OK {
    param([string]$Text)
    Write-Host "  [OK] $Text" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Text)
    Write-Host "  [!] $Text" -ForegroundColor Yellow
}

function Write-Fail {
    param([string]$Text)
    Write-Host "  [FAIL] $Text" -ForegroundColor Red
}

function Get-KenneyDownloadUrl {
    <#
    .SYNOPSIS
      Scrapes kenney.nl asset page HTML to extract the direct download ZIP URL
      from the donation modal (id='donate-text' href).
    #>
    param([string]$PageUrl)

    try {
        $html = Invoke-WebRequest -Uri $PageUrl -UseBasicParsing -TimeoutSec 30
        # Find the download link in the inline-download popup
        # Kenney uses single-quoted HTML attributes: href='URL'
        $pattern1 = "id='donate-text' href='([^']+)'"
        $match = [regex]::Match($html.Content, $pattern1)
        if ($match.Success) {
            $downloadUrl = $match.Groups[1].Value
            return $downloadUrl
        }
        # Fallback: try double-quoted version
        $pattern2 = 'id="donate-text" href="([^"]+)"'
        $match2 = [regex]::Match($html.Content, $pattern2)
        if ($match2.Success) {
            return $match2.Groups[1].Value
        }
        return $null
    } catch {
        Write-Fail "Failed to fetch $PageUrl : $_"
        return $null
    }
}

function Invoke-DownloadAndExtract {
    <#
    .SYNOPSIS
      Downloads a ZIP from a URL, extracts it to the target directory.
    #>
    param(
        [string]$DownloadUrl,
        [string]$TargetDir,
        [string]$PackLabel
    )

    # Create target directory
    if (-not (Test-Path -LiteralPath $TargetDir)) {
        New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    }

    # Check if already extracted (non-empty directory)
    $existingItems = Get-ChildItem -LiteralPath $TargetDir -ErrorAction SilentlyContinue
    if ($existingItems -and ($existingItems.Count -gt 0)) {
        Write-OK "$PackLabel already extracted in $TargetDir ($($existingItems.Count) items)"
        return $true
    }

    # Temporary ZIP path
    $zipPath = Join-Path $env:TEMP "thronehold_$([System.IO.Path]::GetRandomFileName()).zip"

    try {
        Write-Host "  Downloading $DownloadUrl ..." -ForegroundColor Gray
        $wc = New-Object System.Net.WebClient
        $wc.DownloadFile($DownloadUrl, $zipPath)
        $zipInfo = Get-Item $zipPath
        Write-OK "Downloaded $($zipInfo.Length) bytes"

        # Extract
        Write-Host "  Extracting to $TargetDir ..." -ForegroundColor Gray
        Expand-Archive -LiteralPath $zipPath -DestinationPath $TargetDir -Force

        # Verify
        $extractedItems = Get-ChildItem -LiteralPath $TargetDir -Recurse -ErrorAction SilentlyContinue
        $count = if ($extractedItems) { $extractedItems.Count } else { 0 }
        Write-OK "Extracted $count files to $TargetDir"

        return $true
    }
    catch {
        Write-Fail "Download/Extract failed for $PackLabel : $_"
        return $false
    }
    finally {
        # Clean up zip
        if (Test-Path -LiteralPath $zipPath) {
            Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function New-ReadmeForManualPack {
    <#
    .SYNOPSIS
      Creates a README.md with download instructions for packs that can't be auto-downloaded.
    #>
    param(
        [string]$TargetDir,
        [string]$PackLabel,
        [string]$PackUrl,
        [string]$License,
        [string]$Description,
        [string]$AttributionNote,
        [string]$DownloadPage,
        [string]$DownloadNote,
        [string]$Category
    )

    if (-not (Test-Path -LiteralPath $TargetDir)) {
        New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    }

    # Check if README already exists
    $readmePath = Join-Path $TargetDir "README.md"
    if (Test-Path -LiteralPath $readmePath) {
        Write-OK "README already exists for $PackLabel"
        return
    }

    $content = @"
# $PackLabel

**Category:** $Category
**License:** $License
**Source:** [$PackUrl]($PackUrl)

## Description

$Description

## How to Download

This asset pack requires manual download (no stable direct-download URL available).

1. Open this page in your browser: **[$DownloadPage]($DownloadPage)**
2. $DownloadNote
3. Extract the downloaded file(s) into this directory: `$TargetDir`
4. Delete the ZIP/archive after extraction (optional)

## License Notes

$AttributionNote

## Files to Expect After Download

After downloading and extracting, this directory should contain the asset files
(e.g., PNG spritesheets, individual sprites, or other game-ready content).

---
*This README was auto-generated by scripts/download_all_free_assets.ps1*
"@

    Set-Content -LiteralPath $readmePath -Value $content -Encoding UTF8
    Write-OK "Created README for $PackLabel"
}

# --- Main Execution ---------------------------------------------------------

Write-Host @"

===============================================
  Thronehold - Free Asset Downloader
  Downloads massive CC0/CC-BY pixel art collection
  for a self-contained AI-friendly repo
===============================================

"@ -ForegroundColor Magenta

# Create base directories
if (-not (Test-Path -LiteralPath $FreeDir)) {
    New-Item -ItemType Directory -Path $FreeDir -Force | Out-Null
    Write-OK "Created $FreeDir"
} else {
    Write-OK "$FreeDir exists"
}

# --- Phase 1: Download all Kenney packs -------------------------------------
Write-Step "Phase 1: Downloading Kenney Asset Packs (CC0)" "Green"

$kenneyResults = @()
foreach ($pack in $KenneyPacks) {
    Write-Host "`n----------------------------------------" -ForegroundColor DarkGray
    Write-Host "  Pack: $($pack.Label)" -ForegroundColor White
    Write-Host "  URL:  $($pack.Url)" -ForegroundColor DarkGray
    Write-Host "  Dir:  $(Join-Path $FreeDir $pack.Dir)" -ForegroundColor DarkGray
    Write-Host "----------------------------------------" -ForegroundColor DarkGray

    $targetDir = Join-Path $FreeDir $pack.Dir

    Write-Host "  Scraping download URL from page..." -ForegroundColor Gray
    $downloadUrl = Get-KenneyDownloadUrl -PageUrl $pack.Url

    if ($downloadUrl) {
        Write-OK "Found download URL"
        $success = Invoke-DownloadAndExtract -DownloadUrl $downloadUrl -TargetDir $targetDir -PackLabel $pack.Label
        $kenneyResults += @{Name=$pack.Label; Dir=$pack.Dir; DirPath=$targetDir; Success=$success; Category=$pack.Category; Desc=$pack.Desc; License=$pack.License}
    } else {
        Write-Warn "Could not extract download URL. Creating README with instructions."
        New-ReadmeForManualPack -TargetDir $targetDir -PackLabel $pack.Label -PackUrl $pack.Url -License $pack.License -Description $pack.Desc -AttributionNote "License: $($pack.License) - No attribution required." -DownloadPage $pack.Url -DownloadNote "Click the orange Download button on the page, then click 'Continue without donating...'" -Category $pack.Category
        $kenneyResults += @{Name=$pack.Label; Dir=$pack.Dir; DirPath=$targetDir; Success=$false; Category=$pack.Category; Desc=$pack.Desc; License=$pack.License}
    }
}

# --- Phase 2: Manual / README-only packs ------------------------------------
Write-Step "Phase 2: Creating READMEs for Manual-Download Packs" "Yellow"

$manualResults = @()
foreach ($pack in $ManualPacks) {
    $targetDir = Join-Path $FreeDir $pack.Dir
    New-ReadmeForManualPack -TargetDir $targetDir -PackLabel $pack.Label -PackUrl $pack.Url -License $pack.License -Description $pack.Desc -AttributionNote $pack.Note -DownloadPage $pack.DownloadPage -DownloadNote $pack.DownloadNote -Category $pack.Category
    $manualResults += @{Name=$pack.Label; Dir=$pack.Dir; DirPath=$targetDir; Category=$pack.Category; Desc=$pack.Desc; License=$pack.License; Url=$pack.Url}
}

# --- Phase 3: Update assets/README.md ---------------------------------------
Write-Step "Phase 3: Updating assets/README.md" "Green"

$readmePath = Join-Path $AssetDir "README.md"

# Build the asset table rows
$tableRows = @()
$index = 1

# Kenney packs that succeeded
$sortedKenney = $kenneyResults | Sort-Object Name
foreach ($r in $sortedKenney) {
    $status = if ($r.Success) { "Auto-downloaded" } else { "See README" }
    $extractDir = "assets/free_packs/$($r.Dir)/"
    $attribution = if ($r.License -eq "CC0") { "None required" } else { "See license file" }
    $licenseCol = $r.License

    $tableRows += "| $index | **$($r.Name)** | $($r.Category) | $licenseCol | $($r.Desc) | $extractDir | $attribution |"
    $index++
}

# Manual packs
foreach ($r in $manualResults) {
    $extractDir = "assets/free_packs/$($r.Dir)/"
    $attribution = "See README notes"

    $tableRows += "| $index | **$($r.Name)** | $($r.Category) | $($r.License) | $($r.Desc) | $extractDir | $attribution |"
    $index++
}

# Existing packs in repo
$tableRows += "| $index | **Kenney Fantasy UI Borders** | UI Assets | CC0 | 130+ fantasy-themed UI border sprites | assets/ui/kenney/ | None required |"
$index++
$tableRows += "| $index | **BoldPixels Font** | Fonts | CC0 | Pixel art bitmap font family (8px, 16px, 32px) | assets/fonts/ | None required |"
$index++
$tableRows += "| $index | **Gothic Pixel UI** | UI Assets | CC0 | Gothic-themed pixel UI elements | assets/ui/gothic/ | None required |"
$index++
$tableRows += "| $index | **Interface SFX Pack 1** | Audio | CC0 | 200+ UI sound effects | assets/audio/sfx/ | None required |"

$allRows = $tableRows -join "`n"

$readmeContent = @"
# Thronehold - Asset Sources

All assets listed are free to use in commercial and non-commercial projects.
See the **License** column and **Attribution** notes for each asset.

---

## Asset Index

| # | Asset | Category | License | Description | Location | Attribution |
|---|-------|----------|---------|-------------|----------|-------------|
$allRows

---

## Download Status

### Auto-downloaded
These packs were downloaded and extracted automatically by `scripts/download_all_free_assets.ps1`.
They are ready to use.

### Manual download required
These packs have README instructions in their directories.
Run `scripts/download_all_free_assets.ps1` and check each pack's README for download instructions,
or manually download from the source URLs listed above.

---

## Asset Categories

### Terrain and Tilesets
- **Kenney Pixel Platformer** - 16x16 terrain tiles for map building
- **Kenney Roguelike/RPG Pack** - dungeon tiles, characters, items, props
- **16x16 Fantasy Tileset** - gameboy-style retro tiles (CC-BY-SA 3.0)

### UI Assets
- **Kenney Fantasy UI Borders** - ornate frames, panels, and buttons
- **Kenney UI Pack** - modern interface elements (v2.0)
- **Kenney Input Prompts Pixel** - controller/keyboard glyphs
- **Gothic Pixel UI** - dark fantasy themed UI elements

### Icons and Resources
- **Kenney Game Icons** - controller and interface icons
- **Kenney Cursor Pixel Pack** - pixel art cursors
- **Ravenmore Strategy Resource Icons** - gold, food, wood, stone icons

### Fonts
- **Kenney Fonts** - 11 pixel/bitmap font families
- **Press Start 2P** - popular retro pixel font (Google Fonts, OFL)
- **BoldPixels Font** - pixel font in multiple sizes

### Audio
- **Kenney Interface Sounds** - 100+ UI click/hover sounds
- **Kenney RPG Audio** - 50+ RPG foley/weapon sounds
- **Kenney Music Jingles** - 85+ short musical stings/fanfares
- **Interface SFX Pack 1** - 200+ UI sound effects

---

## License Summary

| License | Usage | Attribution Required |
|---------|-------|---------------------|
| **CC0** (Creative Commons Zero) | Public domain. Free for any purpose, commercial or non-commercial. | No |
| **CC-BY 3.0/4.0** | Free to use, must credit author. | Yes |
| **CC-BY-SA 3.0** | Free to use, must credit author, share-alike. | Yes |
| **OFL** (Open Font License) | Free to use, fonts can be embedded in projects. | No (but appreciated) |

All Kenney assets are **CC0** - no attribution needed but appreciated:
> *"Kenney (www.kenney.nl)"*

---

## Additional Free Asset Resources

| Site | URL | Notes |
|------|-----|-------|
| Kenney.nl | <https://kenney.nl> | Hundreds of CC0 game asset packs |
| OpenGameArt.org | <https://opengameart.org> | Filter by CC0 license |
| itch.io | <https://itch.io/game-assets/free> | Filter: Free / CC0 |
| Freesound.org | <https://freesound.org> | Filter by Creative Commons 0 |
| Google Fonts | <https://fonts.google.com> | Free fonts, OFL licensed |
| Soniss GDC Audio Packs | <https://soniss.com/audio-packs/> | Annual CC0 SFX bundles |

---

## Visual Style Guide

This collection provides assets for a **16x16 pixel art strategy game** with a fantasy theme:

| Element | Source Pack | Notes |
|---------|-------------|-------|
| Map terrain tiles | Kenney Pixel Platformer | 18x18 tiles, mix and match |
| Dungeon interiors | Kenney Roguelike RPG Pack | 16x16 tiles, furniture, walls |
| UI panels and buttons | Kenney Fantasy UI Borders + UI Pack | Fantasy borders + modern UI |
| Input prompts | Kenney Input Prompts Pixel | 16x16 controller/keyboard icons |
| Cursors | Kenney Cursor Pixel Pack | 16x16 pixel cursors |
| Resource icons | Ravenmore Strategy Icons | Gold, food, wood, stone, etc. |
| Unit icons/Avatars | Kenney Roguelike RPG Pack | Character sprites, 16x16 |
| Fonts | Kenney Fonts / Press Start 2P | Retro pixel fonts |
| SFX | Kenney Interface Sounds + RPG Audio | UI clicks, footsteps, weapons |
| Music | Kenney Music Jingles | Jingles for events |

---

*Last updated: 2026-05-27 - Generated by scripts/download_all_free_assets.ps1*
"@

Set-Content -LiteralPath $readmePath -Value $readmeContent -Encoding UTF8
Write-OK "Updated $readmePath"

# --- Summary -----------------------------------------------------------------
Write-Host @"

===============================================
              DOWNLOAD SUMMARY
===============================================

"@ -ForegroundColor Magenta

$successCount = ($kenneyResults | Where-Object { $_.Success }).Count
$failCount = ($kenneyResults | Where-Object { -not $_.Success }).Count
$manualCount = $manualResults.Count

Write-Host "  Kenney packs downloaded:   $successCount / $($kenneyResults.Count)" -ForegroundColor Green
if ($failCount -gt 0) {
    Write-Host "  Kenney packs with READMEs: $failCount" -ForegroundColor Yellow
}
Write-Host "  Manual packs with READMEs: $manualCount" -ForegroundColor Cyan
Write-Host "  Total packs:               $($kenneyResults.Count + $manualCount)" -ForegroundColor White
Write-Host "`n  All assets in: $FreeDir" -ForegroundColor White
Write-Host "  Asset index:   $readmePath" -ForegroundColor White

Write-Host @"

  -------------------------------------------------
  Assets downloaded successfully!
  The repo is now self-contained with free CC0
  pixel art for Thronehold.
  -------------------------------------------------

"@ -ForegroundColor Green
