# Project themes

- **Minimal Elevation**: `theme_main.tres`, the current project default.
- **Casual Pop / Refined**: `theme_casual_pop.tres`, a complete dark control set
  with soft elevation, restrained gradients, fine borders, and original icons.

Run `casual_pop_preview.tscn` with F6 to try every control and the live color pickers.
Preview edits are temporary and do not modify either saved theme.

To use the second theme, drag `theme_casual_pop.tres` onto a root Control's Theme
property, or select it in Project Settings > GUI > Theme > Custom and restart.
An explicit scene theme takes precedence over the project default. Scene font
overrides and ColorRect backgrounds also remain independent of the theme.

Select the Casual Pop resource in the Inspector to edit Accent Color, Gradient
Color, Gradient Strength, Success Color, Warning Color, Danger Color, Surface
Color, Corner Radius, and Elevation. Gradient Strength = 0 removes the color
transition. Surface Color is intended for dark palettes.
The tool script rebuilds matching hover, pressed, focus, and progress styles,
including the checkbox, radio, switch, and slider artwork. Changing a loaded
resource affects all controls sharing it; create an instance for local palettes.
Save the resource to keep palette changes. Generated theme items should be
customized through the script, as rebuilding replaces manual style edits.

For a separate runtime palette, create an independent theme instance:

```gdscript
const CasualTheme = preload("res://resources/theme/casual_pop_theme.gd")

func _ready() -> void:
    theme = CasualTheme.new()
    theme.accent_color = Color("bca0ff")
```

Button variations: PrimaryButton, SuccessButton, WarningButton, DangerButton,
OutlineButton. The base Button is a neutral raised action.
Label variations: TitleLabel, LabelSmall, BadgeLabel.
PanelContainer variation: AccentPanel (fine colored top edge).

Dedicated styles cover MenuButton, OptionButton and PopupMenu; CheckBox (including
ButtonGroup radios) and CheckButton; LineEdit and TextEdit; TabBar and TabContainer;
HSlider, VSlider, ProgressBar, and both scrollbars. Selection controls use their own
indicators instead of inheriting raised button backgrounds. Native OS menus, if
explicitly enabled on a control, are drawn by the OS and cannot use this theme.

Menus are quiet text actions. Godot's MenuButton defaults to accessibility-only
focus; set Focus Mode to All if it should participate in Tab navigation, as the
preview does. Tabs and field focus rings use accent color. Sliders retain native
Godot behavior, including arrow keys and tick snapping. Multiline fields need
enough height for their intended rows plus 24 px of vertical padding.

The original direction came from Super Casual; this revision references all 34
images in [gamevanilla's Ultimate Clean GUI Pack](https://assetstore.unity.com/packages/2d/gui/ultimate-clean-gui-pack-154574),
particularly its Round Dark and Modern Dark control sheets. The generated SVG
icons and nine-sliced gradient StyleBoxes are original; no store artwork or
purchased assets are required. DPITexture stores the compact SVG source and
rasterizes at the active UI scale. The theme uses the bundled Lato fonts.

Verification (Godot 4.8-dev4):

```sh
GODOT=/Applications/Godot_v4.8-dev4.app/Contents/MacOS/Godot
"$GODOT" --headless --path . res://resources/theme/tests/casual_pop_smoke.tscn
"$GODOT" --path . --rendering-method gl_compatibility res://resources/theme/tests/casual_pop_smoke.tscn -- --visual
```

Headless mode checks control coverage, stable state sizing, keyboard behavior,
palette updates, independent instances, and resource save/reload. Visual mode
writes overview, popup, focus, RTL, and alternate-palette PNGs to `/tmp`; it holds
popups open for capture so desktop focus changes cannot dismiss them.
