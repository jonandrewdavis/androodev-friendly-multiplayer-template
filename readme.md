# AndrooDev "Friendly" Multiplayer Template

A Godot game template with many ways to connect. Designed to make starting your co-op or friendly game easy.

### Overview

This template is based on two other great templates. Check them out here:

- [Godot Game Template, also GGT for short](https://github.com/crystal-bit/godot-game-template/tree/main)
- [swAAn01's Godot Multiplayer Platform](https://github.com/swAAn01/Godot-Multiplayer-Platform)





              |
# Features Overview

GGT is composed of multiple parts:

1.  **ggt-core** addon
2.  **ggt-shortcuts** addon
3.  Godot project boilerplate (this repository)

**ggt-core** provides:

- Scene management with transitions and optional progress bar
- Parameter passing between scenes
- Multithreaded scene loading
  - single threaded loading fallback for web exports
- Settings for audio volume for Master/SFX/BGM buses, language selection, resolution scale, FPS limit, vsync. 
  - settings persisted via Godot's ConfigFile
- gettext (.pot) localization setup with 2 languages (English, Italian). Feel free to add new languages via PR
  - bash script to sync all .po files with a single command 

**ggt-shortcuts** provides:

- Debug shortcuts mapped to keyboard keys for restart (R), pause frame (P), advance frame (.), speed up time scale (SHIFT), quit (Q)
  - easily configurable via Godot Input Map
- Automatic shortcuts removal for release builds

The godot project boilerplate provides:

- GitHub Actions workflows for automatic builds+web deploy on Github Pages after each commit (thanks to [aBARICHELLO/godot-ci](https://github.com/aBARICHELLO/godot-ci))
  - or you can use manual workflow dispatch
  - or you can use a local `release.sh` script to export multiple targets (Windows, Linux, Mac, ...) with a single command
  - or you can export manually from Godot as usual
- A project structure that follows Godot best practices and naming conventions
- Placeholder menu and gameplay scenes with support for keyboard, gamepad or touch inputs
- A preconfigured global theme for control nodes. Tweak `resources/theme/theme_main.tres` and every control node will inherit from it.

## Multiplayer

Choose a Service in the main menu: LAN (ENet) uses your local network; Online (NodeTunnel) uses a relay without port forwarding. Host a game or open Join to discover rooms or enter an address directly. Hosting with one player starts offline.

Press Escape in game to open the pause menu. Hosts can share the LAN address or NodeTunnel room code shown there, change levels, and kick or ban players. Leave Game returns to the main menu. NodeTunnel bans use temporary peer IDs and do not identify a player across reconnects.

NodeTunnel v1.1.1_beta is bundled for macOS, Linux and Windows. Web exports are not supported by this native plugin. The relay is `us-east.nodetunnel.io:8080`, using App ID `0ahb6lkmhi5dtfi`. LAN gameplay uses UDP 3005 and discovery uses UDP 3006.

Player departures and relay disconnections use NodeTunnel's native signals and timing; no custom presence tracking or in-game timeout is applied.

To add a backend, implement `MultiplayerBackend` and register its enum value, script and display label in `globals/networking/multiplayer_service.gd`. The selected service is saved in the game's settings.

# Get started

You have 2 options:

## 1. Get started with Github Templates:

1. [Create a new repo using this template](https://github.com/crystal-bit/godot-game-template/generate)
2. Clone the new repository locally
3. Open the project in [Godot](https://godotengine.org/download/) (GDScript)

## 2. Get started with a local project:

1. Go to https://github.com/crystal-bit/godot-game-template/releases
2. Download _Source code (zip)_
3. Unzip the project
4. Open the project in [Godot Engine](https://godotengine.org/download/) (GDScript) and create your game!

# How to...

## Change scene

```gdscript
GGT.change_scene("res://scenes/gameplay/gameplay.tscn")
```

![change_scene](https://user-images.githubusercontent.com/6860637/162567110-026c1979-6237-4255-bb2a-97815fc4b0c4.gif)

## Change scene and show progress bar

```gdscript
GGT.change_scene("res://scenes/gameplay/gameplay.tscn", {
  "show_progress_bar": true
})
```

![progress](https://user-images.githubusercontent.com/6860637/162567097-81b5c54e-1ee5-42b9-a583-60764ecff069.gif)

## Change scene and pass parameters

```gdscript
var params = {
  "level": 4,
  "skin": "dark"
}
GGT.change_scene("res://scenes/gameplay/gameplay.tscn", params)
```

Nodes in the loaded scene can read params with:

```gdscript
# gameplay.gd

func _ready():
    var params = GGT.get_current_scene_data().params
    print(params.level) # 4
    print(params.skin)  # 'dark'
   # setup your scene here
```

## Await scene transition to finish

Note: all the tree is already paused during scene transitions, but if you need to
wait for the graphic transition to completely disappear before calling some code you
can use this approach:

```gdscript
# gameplay.gd

func _ready() -> void:
    if GGT.is_changing_scene(): # this will be false for the starting scene or if you start the scene with "Run current scene" or F6 shortcut during development
        await GGT.scene_transition_finished
    # activate your game logic here
    pass
```

## Restart the current scene

```gd
GGT.restart_scene() # old params will be reused
```

## Restart the current scene and override params

```gd
var new_params = {
  "level": 5,
}
GGT.restart_scene_with_params(new_params)
```

# addons/ggt-debug-shortcuts

`addons/ggt-debug-shortcuts` is enabled by default and it builds on top of `ggt-core`.

By default it will set these input actions to the project:

| action                    | key        | description                                                  |
| ------------------------- | ---------- | ------------------------------------------------------------ |
| "ggt_debug_pause_game"    | KEY_P      | Pauses the tree                                              |
| "ggt_debug_step_frame"    | KEY_PERIOD | It advances 1 process_frame and 1 physics_frame during pause |
| "ggt_debug_restart_scene" | KEY_R      | Restarts the current scene, with the same parameters         |
| "ggt_debug_quit_game"     | KEY_Q      | Closes the game                                              |
| "ggt_debug_speedup_game"  | KEY_SHIFT  | Sets Engine.time_scale to 2 while holding key                |

You can change, remove or add shortcuts in [debug_shortcuts.gd](./addons/ggt-debug-shortcuts/autoload/debug_shortcuts.gd).

**These shortcuts work in the editor and in debug builds and are automatically removed on release builds.**

# Conventions and project structure

- `assets/`
  - Contains textures, sprites, sounds, music, fonts, ...
- `builds/`
  - output directory for game builds generated via `release.sh` (ignored by .gitignore and .gdignore)
- `scenes/`
  - Contains Godot scenes (both entities, reusable scenes and "game screen" scenes)
  - Scene folders can contain `.gd` scripts or resources used by the scene

Mostly inspired by the official [Godot Engine guidelines][l1]:

- **snake_case** for files and folders (eg: game.gd, game.tscn)
- **PascalCase** for node names (eg: Game, Player)

[l1]: https://docs.godotengine.org/en/stable/getting_started/workflow/project_setup/project_organization.html#style-guide

### Lower Case file names

This convention avoids having filesystem issues on different platforms. Stick with it
and it will save you time. Read more
[here](https://docs.godotengine.org/en/stable/getting_started/workflow/project_setup/project_organization.html#case-sensitivity):

> Windows and recent macOS versions use case-insensitive filesystems by default,
> whereas Linux distributions use a case-sensitive filesystem by default. This
> can cause issues after exporting a project, since Godot's PCK virtual
> filesystem is case-sensitive. To avoid this, it's recommended to stick to
> snake_case naming for all files in the project (and lowercase characters in
> general).

See also [this PR](https://github.com/godotengine/godot/pull/82957/files) that adds `is_case_sensitive()`.

### Trim whitespaces on save

If every developer on the team is using the built-in Godot Engine text editor I strongly suggest
to activate this option:

- Editor -> Editor Settings -> Text Editor/Behaviour -> Trim Trailing Whitespace on Save

It avoids whitespace changes that may add noise in team work.

# Export utilities

## `release.sh`

From your project root:

```sh
./release.sh # this assumes that you have a "godot" binary/alias in your $PATH
```

Look inside the ./builds/ directory:

```sh
builds
└── ProjectName
    ├── html5
    │   ├── build.log # an export log + build datetime and git hash
    │   ├── index.html
    │   ├── ...
    ├── linux
    │   ├── ProjectName.x86_64
    │   └── build.log
    ├── osx
    │   ├── ProjectName.dmg
    │   └── build.log
    └── windows
        ├── ProjectName.exe
        └── build.log
```

## Github Actions

If you are using Github you can take advantage of:

1. automatic exports for every commit push (see [push-export.yml][ci-push-export])
2. manual exports via Github CI (see [dispatch-export.yml][ci-dispatch] )

[ci-push-export]: ./.github/workflows/push-export.yml
[ci-dispatch]: ./.github/workflows/push-export.yml

You can read more on [Wiki - Continuos Integration][wiki_ci]

[wiki_ci]: https://github.com/crystal-bit/godot-game-template/wiki/1.-Continuous-integration-(via-GitHub-Actions)

# Contributing

If you want to help the project, create games and feel free to get in touch and report any issue.

![Discord](https://img.shields.io/discord/686600734636376102?logo=discord&logoColor=ffffff&color=7389D8&labelColor=6A7EC2)

You can also join [the Discord server](https://discord.gg/SA6S2Db) (`#godot-game-template` channel).

Before adding new features please open an issue to discuss it with other contributors.

## Contributors

Many features were implemented only thanks to the help of:

- [Andrea-Miele](https://github.com/Andrea-Miele)
- [Fahien](https://github.com/Fahien)
- [Andrea1141](https://github.com/Andrea1141)
- [vini-guerrero](https://github.com/vini-guerrero)
- [idbrii](https://github.com/idbrii)
- [jrassa](https://github.com/jrassa)

Also many tools were already available in the open source community, see the [Thanks](#thanks) section.

# Thanks

- For support & inspiration:
  - All the [contributors](https://github.com/crystal-bit/godot-game-template/graphs/contributors)
  - Crystal Bit community
  - GameLoop.it
  - Godot Engine Italia
  - Godot Engine
- For their work on free and open source software:
  - [aBARICHELLO](https://github.com/aBARICHELLO/godot-ci)
  - [croconut](https://github.com/croconut/godot-multi-builder)
  - [josephbmanley](https://github.com/josephbmanley)
  - [GDQuest](https://github.com/GDquest)
  - [Scony](https://github.com/Scony)
  - [myood](https://github.com/myood)
