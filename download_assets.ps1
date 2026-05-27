# download_assets.ps1
# Downloads Kenney Fantasy UI Borders pixel art asset pack
# Place extracted files in assets/ui/kenney/
#
# Sources:
#   - Kenney.nl:    https://kenney.nl/assets/fantasy-ui-borders (recommended)
#   - Itch.io:      https://kenney-assets.itch.io/fantasy-ui-borders
#
# License: CC0 (Public Domain) - Free for any use, no attribution required
# =============================================================================

$OutputDir = "assets/ui/kenney"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Kenney Fantasy UI Borders - Asset Download " -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This script helps you download free CC0 pixel-art UI assets"
Write-Host "from Kenney, one of the best sources for game art."
Write-Host ""

# --- Create output directory ---
if (-not (Test-Path -LiteralPath $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    Write-Host "[OK] Created directory: $OutputDir" -ForegroundColor Green
} else {
    Write-Host "[OK] Directory exists: $OutputDir" -ForegroundColor Yellow
}

# --- Instructions ---
Write-Host ""
Write-Host "=== DOWNLOAD INSTRUCTIONS ===" -ForegroundColor White
Write-Host ""
Write-Host "Option A: Kenney.nl (recommended - no account needed)"
Write-Host "  Step 1: Open this URL in your browser:"
Write-Host "          https://kenney.nl/assets/fantasy-ui-borders" -ForegroundColor Cyan
Write-Host "  Step 2: Click the orange 'Download' button"
Write-Host "  Step 3: Extract the ZIP file"
Write-Host ""
Write-Host "Option B: Itch.io (free, $0 - account required)"
Write-Host "  Step 1: Open this URL in your browser:"
Write-Host "          https://kenney-assets.itch.io/fantasy-ui-borders" -ForegroundColor Cyan
Write-Host "  Step 2: Click 'Download' (set price to $0 if needed)"
Write-Host "  Step 3: Extract the ZIP file"
Write-Host ""
Write-Host "=== EXTRACTION ===" -ForegroundColor White
Write-Host ""
Write-Host "After downloading, copy the PNG files from the ZIP into:"
Write-Host "  $($PWD.Path)/$OutputDir" -ForegroundColor Cyan
Write-Host ""
Write-Host "Expected files (found inside the pack):"
Write-Host "  panel_brown.png        - Main panel texture" -ForegroundColor Green
Write-Host "  panel_beige.png        - Light panel texture" -ForegroundColor Green
Write-Host "  panel_blue.png         - Blue accent panel" -ForegroundColor Green
Write-Host "  button_blue.png        - Button normal state" -ForegroundColor Green
Write-Host "  button_blue_pressed.png - Button pressed state" -ForegroundColor Green
Write-Host "  button_red.png         - Red button variant" -ForegroundColor Green
Write-Host "  button_yellow.png      - Yellow button variant" -ForegroundColor Green
Write-Host "  bar_background.png     - Progress bar background" -ForegroundColor Green
Write-Host "  bar_fill_green.png     - Progress bar fill" -ForegroundColor Green
Write-Host "  cross.png              - Close/exit icon" -ForegroundColor Green
Write-Host "  ... and more UI elements" -ForegroundColor Green
Write-Host ""
Write-Host "=== VERIFICATION ===" -ForegroundColor White
Write-Host ""

# Check what's already there
$existingFiles = Get-ChildItem -LiteralPath $OutputDir -Filter "*.png" -ErrorAction SilentlyContinue
if ($existingFiles) {
    Write-Host "Files already in $OutputDir :" -ForegroundColor Yellow
    foreach ($f in $existingFiles) {
        Write-Host "  - $($f.Name)" -ForegroundColor Green
    }
} else {
    Write-Host "No PNG files found yet. Complete the extraction steps above." -ForegroundColor Red
}

Write-Host ""
Write-Host "=== AUTO-LOAD INFO ===" -ForegroundColor White
Write-Host ""
Write-Host "The game will automatically detect and use these textures when"
Write-Host "they exist. If the files are missing, it falls back to the"
Write-Host "existing dark theme - no crashes, no errors."

Write-Host ""
Write-Host "Happy modding!" -ForegroundColor Cyan
