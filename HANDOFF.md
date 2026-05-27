# Thronehold — Handoff

## Quick Start
```
launch.bat  →  Opens game in Godot
```

## Current State

### ✅ Working
- **Headless compile**: Zero errors. All 4 startup checks pass.
- **Game systems**: AI raids, tech research, subrace emergence, monster spawning, artifacts, factions, colonies, diplomacy, doctrines, and more — all run correctly.
- **Auto-play**: When enabled, generates world, 8-9 nations, runs simulation. Log at `C:\Users\User\AppData\Roaming\Godot\app_userdata\Thronehold\logs\godot.log`
- **Vision QA**: Works via `multimodal-looker` subagent (routes to `gemini/gemini-2.5-flash`). Screenshots at `C:\Users\User\AppData\Roaming\Godot\app_userdata\Thronehold\world_map.png`

### ⚠️ GUI Mode — GameUI.gd Parse Errors
The game compiles in headless but GUI mode fails on GameUI.gd. The `bg_1f09db7e` fix agent renamed duplicate variables across 14 locations but left 3 collateral issues with indentation and variable scope in lambdas.

**Known remaining errors (~3):**
1. `GameUI.gd:1250` — `tx` not in scope. `_refresh_building_selection` function — `tx` is `_hovered_tile_x` at top of file (line 10) but the fix agent's indentation restructure broke the scope. Fix: find where `tx` and `ty` are set in the function and capture them before lambdas use them.
2. Possible additional indentation issues in the same function (~lines 1220-1260).

**Approach**: Read `_refresh_building_selection` from line ~1080 to end of function. The fix agent renamed `for r` → `for _r`/`for _rc`, `for b_on_tile` → `for _b_on_tile`, `var bid` → `var _bid` but indentation of the surrounding blocks was disturbed.

### Project Config
- **Godot 4.6.2**: `C:\Users\User\Documents\GitHub\NG\Godot_v4.6.2-stable_win64.exe`
- **Timeout**: Set to 60min in `C:\Users\User\.config\opencode\oh-my-openagent.json` (`staleTimeoutMs: 3600000`)
- **Untyped vars**: `warnings/untyped_declaration=0` in project.godot

## ⚠️ CRITICAL: Always Use Fresh Screenshots From Current Game Instance
- **NEVER analyze old screenshots.** The `world_map.png` at `C:\Users\User\AppData\Roaming\Godot\app_userdata\Thronehold\` is from a previous auto-play session and does NOT reflect the current game state.
- **Capture fresh every time**: Run the game, take a NEW screenshot of what's actually on screen, analyze THAT.
- **Vision only shows what was captured.** If the user says "grey screen" — capture a fresh screenshot of the grey screen and analyze THAT, not the old world_map.png.
- **Match vision analysis to user's description**: If the user sees grey, the screenshot should show grey. If they see the menu, the screenshot should show the menu. Do NOT show them an old gameplay screenshot and claim "this is what you should see."

### Vision Tool Usage
- Use `task(subagent_type="multimodal-looker", ...)` — routes to Gemini 2.5 Flash
- Do NOT use `look_at` tool directly — goes through DeepSeek (no image support)
- Screenshots save to: `C:\Users\User\AppData\Roaming\Godot\app_userdata\Thronehold\`
- **Always capture fresh before analyzing** — old screenshots are misleading

### How to Capture Fresh Screenshots
```bash
# Run game (captures world_map.png on load)
& "C:\Users\User\Documents\GitHub\NG\Godot_v4.6.2-stable_win64.exe" --path "C:\Users\User\Documents\GitHub\Auto Strategy" --quit-after 600
```
Or modify `main.gd` temporarily to capture at specific game states.

### Known Ghost Tasks
The 11 stale tasks (race system, CharacterManager, etc.) re-inject every session. All completed. Ignore them.

## Dev Command Pattern
```bash
# Headless test
& "C:\Users\User\Documents\GitHub\NG\Godot_v4.6.2-stable_win64.exe" --headless --path "C:\Users\User\Documents\GitHub\Auto Strategy" --check-only

# GUI test (screenshots captured)
& "C:\Users\User\Documents\GitHub\NG\Godot_v4.6.2-stable_win64.exe" --path "C:\Users\User\Documents\GitHub\Auto Strategy" --quit-after 600

# Vision analysis
task(subagent_type="multimodal-looker", description="Vision: ...", prompt="Analyze screenshot at C:\Users\User\...")

# Bug fix (single file)
task(category="quick", description="...", prompt="...")

# Complex fix (multi-file)
task(category="deep", description="...", prompt="...")
```

## File Summary
- **~40 .gd files** — all systems
- **GameUI.gd**: 3668 lines — main UI, 12 tabs, programmatic
- **ColonyData.gd**: ~1100 lines — all game data
- **main.gd**: ~170 lines — bootstrap, camera, input
- **project.godot**: Autoloads: GameManager, EventBus, ColonyData, DebugManager
