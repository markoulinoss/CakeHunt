# Birthday Cake Hunt 🎂

A short birthday-gift adventure game made with [LÖVE2D](https://love2d.org/) (Lua).

## Playing the standalone build (no LÖVE needed)

A ready-to-run Windows build lives in `dist/`:

- `dist/CakeHunt/` — extract-and-play folder: double-click `CakeHunt.exe`.
- `dist/CakeHunt-win64.zip` — the same folder zipped for sharing.

The DLLs must stay next to the exe, so share the whole folder (or the zip), not the exe alone. 64-bit Windows only.

## Running from source (development)

Requires LÖVE 11.4 installed. From inside this folder:

```
love .
```

## Controls

| Key | Action |
|-----|--------|
| WASD / Arrow keys | Move player |
| Space / Enter | Interact / advance dialogue |
| E | Interact (alternative) |
| H | Show hint (Stage 2 battle) |
| Escape | Quit |

## Rebuilding the Windows package

1. Zip the game files so `main.lua` sits at the zip root, and rename it `cakeHunt.love`:
   ```powershell
   tar -caf cakeHunt.zip main.lua conf.lua assets luis states systems
   ren cakeHunt.zip cakeHunt.love
   ```
2. Fuse it with `love.exe` (from an installed or portable LÖVE 11.4):
   ```
   copy /b "C:\Program Files\LOVE\love.exe"+cakeHunt.love dist\CakeHunt\CakeHunt.exe
   ```
3. Copy all `*.dll` files and `license.txt` from the LÖVE folder next to `CakeHunt.exe`.
4. Zip the `dist\CakeHunt` folder for distribution.

## Folder structure

```
cakeHunt/
├── main.lua               entry point, game loop, canvas scaling
├── conf.lua               window title / size
├── systems/
│   ├── statemachine.lua   clean state switching
│   ├── dialogue.lua       typewriter text box
│   ├── rhythm.lua         arrow-key sequence minigame (used in S1 & S4)
│   ├── transition.lua     fade-to-black between states
│   ├── collectibles.lua   cookie tracker
│   ├── movement.lua       player movement helpers
│   ├── battle_visuals.lua battle presentation effects
│   ├── settings_ui.lua    settings menu
│   └── luis_instance.lua  shared LUIS UI instance
├── luis/                  LUIS UI library (vendored, see luis/LICENSE)
├── assets/
│   ├── sprites.lua        sprite loading / drawing
│   ├── audio.lua          music + SFX definitions
│   ├── audio/             music and sound files
│   └── *.png, ...         sprite sheets and backgrounds
├── states/
│   ├── intro.lua          title screen + opening cutscene
│   ├── stage1_studio.lua  dance studio — rhythm battle
│   ├── stage2_path.lua    path — Diogenis dialogue battle + Romanos rescue
│   ├── stage3_kitchen.lua kitchen cleanup minigame
│   ├── stage4_finale.lua  backstage pep talk + final rhythm battle
│   └── ending.lua         cake reveal, birthday message, credits
└── dist/                  packaged Windows build
```
