# Project themes

- **Minimal Elevation**: `theme_main.tres`, the current project default.
- **Casual Pop**: `theme_casual_pop.tres`, a more playful alternative with chunky
  lower button edges, rounded cards, bold typography, badges, and colorful actions.

Run `casual_pop_preview.tscn` with F6 to try Casual Pop and its live color pickers.
Preview edits are temporary and do not modify either saved theme.

To use the second theme, drag `theme_casual_pop.tres` onto a root Control's Theme
property, or select it in Project Settings > GUI > Theme > Custom and restart.
An explicit scene theme takes precedence over the project default. Scene font
overrides and ColorRect backgrounds also remain independent of the theme.

Select the Casual Pop resource in the Inspector to edit Accent Color, Success
Color, Warning Color, Danger Color, Surface Color, Corner Radius, and Elevation.
The tool script rebuilds matching hover, pressed, focus, and progress styles.
Save the resource to keep palette changes. Generated theme items should be
customized through the script, as rebuilding replaces manual style edits.

For a separate runtime palette, create an independent theme instance:

```gdscript
const CasualTheme = preload("res://resources/theme/casual_pop_theme.gd")

func _ready() -> void:
    theme = CasualTheme.new()
    theme.accent_color = Color("bca0ff")
```

Button variations: PrimaryButton, SuccessButton, WarningButton, DangerButton.
Label variations: TitleLabel, LabelSmall, BadgeLabel.
PanelContainer variation: AccentPanel (colored top edge).
Standard buttons are neutral, letting the primary actions carry the color.
Unspecified icons and controls fall back to Godot's built-in theme.

Visual reference: [LAYERLAB GUI Pro – Super Casual](https://assetstore.unity.com/packages/2d/gui/gui-pro-super-casual-278534).
All styles here are original Godot StyleBoxes using bundled Lato fonts; no store
artwork or purchased assets are required.
