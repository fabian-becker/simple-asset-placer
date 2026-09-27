<div align="center">
  <img src="branding/github-banner.svg" alt="Simple Asset Placer Banner" width="100%"/>
</div>

---

# 🎯 Simple Asset Placer

**A minimal asset placement plugin for Godot 4.x — drag assets into your scene and transform them with the keyboard, without leaving the viewport.**

Simple Asset Placer does two things well: a compact **asset browser dock** and an **inline keyboard transform engine** that works everywhere — while dragging from the dock, while dragging from the regular FileSystem dock, or while carrying a selection you picked up from the scene. No plugin modes, no preview objects, just the editor extended.

## 🚀 Version 3.0 — The Minimal Rewrite

A from-scratch rewrite (`addons/simpleassetplacer/`) that focuses on two things and removes everything else:

- **Inline keyboard transforms** — Rotate (`X`/`Y`/`Z`), move (`W`/`A`/`S`/`D` + `Q`/`E` height) and scale (`L`/`K`) the selected Node3D nodes directly, even while dragging an asset from the FileSystem dock. No plugin mode, no preview object — just the editor extended. Every key and step value is editable in Godot's own **Editor Settings** under `simple_asset_placer/`.
- **Compact asset browser dock** — thumbnails straight from the engine's `EditorResourcePreview` pipeline, live search, a grouped folder list, native drag-and-drop, and double-click placement with full undo.

Both the dock and the keyboard transforms are configured in Godot's **Editor Settings** under `simple_asset_placer/`. See the [changelog](CHANGELOG.md) for details.

## ✨ Features

### 📂 Asset Browser Dock

- **Grouped list view** — folders become collapsible group headers, assets listed underneath; one clean view for the whole project
- **Engine-native thumbnails** — previews come from Godot's own `EditorResourcePreview` pipeline
- **Live search** — filter assets across the entire tree as you type
- **Native drag & drop** — drag a thumbnail straight into the 3D viewport; double-clicking one instead spawns it under the cursor already picked up, so you can transform it into place before confirming (full undo)
- **Plays well with the FileSystem dock** — assets dragged from the regular FileSystem get the same inline transform support
- **Keep-placing switch** — a checkbox below the asset count that keeps the keep-placing mode on, so a row of assets goes down without holding any modifier

### ⌨️ Inline Keyboard Transforms

- **Works while dragging** — grab an asset (dock *or* FileSystem) and rotate/move/scale the preview before you drop it
- **Pick-up mode** — press `Tab` to grab the current selection; it follows your cursor over surfaces, transform it in place, confirm with `Tab`/`Enter`/`Left Mouse` or cancel with `Esc`/`Right Mouse`
- **Quick duplicate stamp** — press `V` to duplicate the selection and carry the copies; click to stamp them, `V` again to stamp the placed copies, `Esc`/`Right Mouse` to discard
- **Keep placing** — double-click an asset to spawn one instance you can transform; hold `Shift` while confirming (or turn on the `Keep placing` switch in the dock) and the placed instance stays where it is while a fresh copy of the same asset is carried straight away, so every `Enter`/`Left Mouse` lays down the next piece and wall rows go down with one click each (each placed instance is its own undo step). Confirming a picked-up scene node the same way carries duplicates of it instead, so copies can be stamped from the tree as well
- **Surface snapping** — the carried nodes raycast onto the surface under your cursor; grid snapping follows the editor's **Use Snap** toggle (hold `Ctrl` to temporarily invert, exactly like the engine)
- **Snap to floor** — `PageDown` while carrying drops the selection onto the surface below and locks its height until you adjust height again
- **Self-collision safe** — the pick-up ray ignores the carried node's own collision (including CSG collision bodies)
- **Shortcut shield** — editor shortcuts (Ctrl+S save, Ctrl+X cut, …) are captured while a transform key is active, so your transforms never save or cut the scene
- **Undo batching** — every drag/pick-up/duplicate session is a single undo step; stamped duplicates collapse into one entry per stamp
- **QWERTZ-friendly** — keys are matched by keycap label (logical keycodes), so `Y`/`Z` behave correctly on German layouts

## 🎮 Quick Start

### Installation

1. Download or clone this repository
2. Copy the `addons/simpleassetplacer/` folder into your project's `addons/` directory
3. Enable **Simple Asset Placer** in **Project → Project Settings → Plugins**
4. The **Asset Browser** dock appears in the right panel of the editor

### Place an asset

```
Drag & drop:
1. Drag a thumbnail from the Asset Browser dock (or a file from the FileSystem
   dock) into the 3D viewport.
2. The preview follows your cursor and snaps to surfaces.
3. While dragging, transform it inline:  X/Y/Z rotate · W/A/S/D move ·
   Q/E height · L/K scale · Ctrl/Alt/Shift change step size & direction.
4. Release the mouse to place the asset (one undo step).

Double-click (transform it before placing):
1. Double-click a thumbnail in the Asset Browser dock - one instance is
   spawned under the cursor and picked up.
2. Move the cursor and use the same transform keys to put it in place.
3. Confirm with Enter or Left Mouse (one undo step); Esc or Right Mouse
   drops the instance again.
```

### Move & transform placed nodes

```
1. Select any Node3D node(s) in the scene tree.
2. Press Tab — the selection is picked up and follows your cursor.
3. Transform it with the same keys (rotation, movement, height, scale,
   snapping, snap-to-floor).
4. Confirm with Tab, Enter or Left Mouse — Esc or Right Mouse cancels
   and restores the original transforms.
```

### Stamp duplicates

```
1. Select a node and press V — a duplicate is created and picked up.
2. Left Mouse (or Enter/Tab) stamps the copy in place; press V again to
   stamp the placed copies for a rapid chain of variations.
3. Esc or Right Mouse deletes the copies and restores the original.
```

### Keep placing (place a row of assets)

```
1. Double-click an asset in the Asset Browser dock (or drag one into the
   viewport and hold Shift as you release) - one instance is spawned under
   your cursor and picked up, ready to transform.
2. Move it into place: it follows the cursor over surfaces, snaps to the
   grid and takes the usual transform keys like any picked-up selection.
3. Turn on the "Keep placing" switch below the asset count - or hold Shift
   while confirming - and every confirm keeps placing: the instance stays
   where it is and a fresh copy of the same asset is carried immediately.
4. Confirm each next piece with Enter or Left Mouse: walls line up piece by
   piece with one click each. Turn the switch off (or release Shift on a
   confirm) to stop, or press Esc / Right Mouse to drop the piece still
   under the cursor - every already-placed piece stays. Each one is its own
   undo step.
```

The switch is the same mode as holding Shift, just sticky: it survives editor
restarts (it is stored as the `keep_placing_mode` editor setting) and applies
to drag & drop too, so a dropped asset starts a chain without any modifier
held.

Keep placing also covers existing scene nodes: pick one up (Tab), transform it
and confirm with Shift held (or the switch on) - the node stays where you
confirmed it and a duplicate of it is carried, so the next confirms stamp
copies of it just like the quick-duplicate chain (pick up several nodes and the
whole group is stamped at once). Esc / Right Mouse drops the carried duplicates
and leaves the confirmed nodes alone.

## ⌨️ Controls

All keys and step sizes live in **Editor → Editor Settings → `simple_asset_placer/`** — every action below is remappable.

| Action | Default | Description |
|--------|---------|-------------|
| Pick up selection | `Tab` | Grab the selection; it follows the cursor over surfaces |
| Confirm / drop | `Tab` `Enter` `LMB` | Drop carried nodes at the current position |
| Cancel pickup | `Esc` `RMB` | Restore the original transforms |
| Quick duplicate | `V` | Duplicate selection and carry the copies (stamping) |
| Rotate | `X` `Y` `Z` | Rotate around the X / Y / Z axis |
| Move | `W` `A` `S` `D` | Move on the horizontal plane |
| Height | `Q` `E` | Move up / down |
| Scale | `L` `K` | Scale up / down |
| Snap to floor | `PageDown` | While carrying: drop onto the surface below and lock height |
| Fine modifier | `Ctrl` | Small step (also inverts the snap toggle, engine-style) |
| Large modifier | `Alt` | Big step |
| Reverse modifier | `Shift` | Inverts the direction of the current key |
| Keep-placing modifier | `Shift` | Held while confirming: place the carried instance and carry a fresh copy of the same asset |
| Keep placing switch | — | Dock checkbox below the asset count: the same mode as the keep-placing modifier, but sticky (stored as the `keep_placing_mode` editor setting) |

## ⚙️ Editor Settings

Everything is configured under **Editor → Editor Settings → `simple_asset_placer/`**:

- **Keys** — one setting per action (`*_key`), free-text like `Tab`, `Enter`, `F`, `PageDown`, or single letters
- **Steps** — `rotation_step_degrees` (15°), `move_step` (0.5), `scale_step_factor` (0.1) and their fine/large variants
- **Snap** — `snap_increment`: `0` follows the editor's **Use Snap** toggle with its grid size, `> 0` forces a fixed increment, `< 0` disables snapping while carrying
- **Modes** — `keep_placing_mode`: the dock's **Keep placing** switch, so the mode can also be toggled from here (the dock follows this setting)

## 📁 Supported Asset Formats

The dock lists scene and model files that Godot's import system can preview:

`.tscn` · `.scn` · `.res` · `.tres` · `.glb` · `.gltf` · `.fbx` · `.obj` · `.dae`

Assets must contain mesh or scene data to produce a draggable instance. Surface placement raycasts against collision — for Terrain3D, enable its collision option so the ray finds the ground.

## 📁 Project Structure

```
addons/simpleassetplacer/
├── plugin.cfg                     # Plugin metadata (version 3.1.0)
├── plugin.gd                      # Plugin entry point
├── core/
│   ├── inline_transform.gd        # Inline keyboard transform engine
│   └── keybinds.gd                # Keys and step sizes (Editor Settings)
└── ui/
    └── asset_dock.gd              # Asset browser dock
```

*Note: For detailed version history, see [CHANGELOG.md](CHANGELOG.md).*

## 🔧 Troubleshooting

- **Dock is empty** — click the **Refresh** button in the dock header; only the formats listed above appear
- **Thumbnails missing or stale** — previews are generated by the engine; use Refresh, or check the asset imports in the FileSystem dock
- **Transform keys do nothing** — click into the 3D viewport first so it has focus; keys apply only to the 3D scene while the mouse is over it
- **A key opens the wrong editor shortcut** — that's what the shortcut shield is for; it engages while you hold a transform key. If a conflict remains, remap the action in Editor Settings
- **Node snaps while snapping is off** — grid snapping follows the editor's **Use Snap** toggle (toolbar); hold `Ctrl` to invert it temporarily, or set `snap_increment` to a negative value to disable it entirely
- **Carried node flies away or collides** — fixed in 3.0: the pick-up ray skips the carried node's own collision; use `PageDown` to re-seat it on the floor

## 🤝 Contributing

Contributions are welcome! Open issues with your Godot version, OS and reproduction steps, and keep pull requests focused. Code style: typed GDScript, snake_case, tabs (see `.editorconfig`), and an updated `CHANGELOG.md`.

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

## 🏆 Credits

**Author**: IIFabixn (aka LuckyTeapot)
**Repository**: [github.com/IIFabixn/simple-asset-placer](https://github.com/IIFabixn/simple-asset-placer)
**Version**: 3.1.0 · **Godot**: 4.x (developed and tested on 4.7) · **License**: MIT

Thanks to the Godot Engine team and community, and to everyone who tested and gave feedback.