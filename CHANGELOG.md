# Changelog

## [3.0.0] - 2026-09-26

### 🚀 Complete Rewrite — Version 3.0

A from-scratch rewrite focused on simplicity, shipping as a single addon (`addons/simpleassetplacer/`)
that replaces 2.x entirely.

### ✨ New Features

#### Inline Keyboard Transforms (Engine Extension)

- **Direct Keyboard Transforms on Selected Nodes**: Rotate/move/scale the current Node3D selection with no
  plugin mode, no preview object, no overlays - the plugin just extends the editor
  - Works while dragging an asset from any dock into the viewport - the drag preview itself is transformed
    and the transform transfers onto the instantiated nodes when dropped - or with any current selection
    while the mouse is over the 3D viewport
  - Rotate: `X` / `Y` / `Z` (stepped, hold-to-repeat, world-space axes)
  - Move: `W` / `A` / `S` / `D` (stepped like rotation, hold-to-repeat, camera-snapped to XZ axes,
    default 0.5 per step) + `Q` / `E` world height
  - Scale: `L` / `K` (stepped multiplicative, clamped to a 0.01 minimum)
  - Modifiers: `CTRL` fine (x0.1) - `ALT` large (x5) - `SHIFT` reverses direction
  - **Pick-Up Gating**: Scene nodes only respond to the transform keys after pressing the
    pickup key (default `Tab`, configurable) - the picked selection then follows the mouse
    cursor like a drag preview (surface placement ray with collision, falling back to the
    pickup-depth plane), move keys nudge it on top of that, `Enter`/`Tab`/LMB confirm and
    drop the pickup, `Escape`/RMB (configurable keys) resets every touched node to its
    pickup-time transform and drops the pickup; works regardless of the mouse position,
    ends automatically on deselect, and shows a dock hint with the carried nodes - file-drag preview transforms
    stay pickup-free
  - **Quick Duplicate (Stamp)**: `V` (configurable) copies the current Node3D selection
    in place and picks the copies up for placement - they follow the mouse like a drag
    preview, LMB/`Enter`/`Tab` stamps them down as one undoable action, `Escape`/RMB
    removes the fresh copies again, and stamping again duplicates the placed copies
  - **Grid Snapping**: the mouse-follow quantizes the cursor point to the editor's
    translate snap increment (the same value the viewport Snap menu configures, read
    live from the editor); `snap_increment` in the Editor Settings chooses
    `0` = follow the editor, `> 0` = fixed increment, `< 0` = off, and the fine
    modifier (Ctrl) gives 1/10 steps
  - **Snap Toggle Aware**: in "follow the editor" mode the follow snap also mirrors
    the spatial editor toolbar's Use Snap toggle state (holding Ctrl inverts it,
    exactly like gizmo dragging), so snapping now turns off with the toolbar toggle
  - **Confirm Click Isolation**: the confirming LMB press and its release are both
    consumed at the editor's root input stage, so the editor's internal click-select
    can no longer override the plugin's post-confirm selection (e.g. a stamped
    duplicate no longer loses the selection to whatever sits under the cursor)
  - **Exact Resting Height**: pick-up follow snaps the surface contact point to the
    grid before applying the bounds-on-surface lift, so picking up a placed node no
    longer sinks it by the rounded difference (grid snap now only quantizes the
    contact point, never the resting height)
  - **Self-Collision Skip**: the follow ray ignores the carried nodes' own collision,
    including CSG shapes with `use_collision` (their internal physics body is not a
    scene node and was missed by the RID pre-collection) - the carried node can no
    longer ray-cast onto itself and climb away
  - **Snap to Floor (Page Down)**: while carrying, `PageDown` (configurable
    `snap_to_floor_key`) drops the carried selection onto the surface directly below
    it - skipping its own collision like the follow ray - and keeps the mouse-follow
    height locked there (XZ keeps following); height keys (Q/E) or a new pickup
    release the lock, and re-pressing re-snaps under the current position
  - **Shortcut Shield**: while the plugin owns the keyboard (pickup or drag) it swallows
    transform keys at the editor's root input stage, so fine/large-step combos like
    Ctrl+S (move down), Ctrl+X (rotate), Ctrl+Z (rotate), Ctrl+A (move left) or Ctrl+D
    (move right) no longer trigger Save, Cut, Undo, Select All, Duplicate or tool
    switching mid-transform; outside sessions editor shortcuts work untouched
  - Keys are matched against keycap labels on every keyboard layout (logical keycodes)
    so `Y`/`Z` behave correctly on QWERTZ keyboards
  - Changes batch into single undoable actions - one Ctrl+Z restores the whole burst
  - Plain transform keys are consumed only while transforms can run, so editor shortcuts
    (Q/W/E/R tool switching, CTRL+S save, ...) keep working otherwise
  - Files: `addons/simpleassetplacer/core/inline_transform.gd`, `addons/simpleassetplacer/core/keybinds.gd`, `addons/simpleassetplacer/plugin.gd`

#### Keybinds via Godot's Editor Settings

- **Native Editor Settings Integration**: Every key and step value lives under `simple_asset_placer/` in
  Editor Settings - editable with Godot's own UI, no custom settings panel, refreshed live on change
  - Files: `addons/simpleassetplacer/core/keybinds.gd`
- **Legacy Settings Cleanup**: On first startup the plugin removes editor settings left behind by the
  removed 2.x addon and pre-release 3.0 builds (old prefixes and categories/ui/browser entries),
  keeping only its own current settings

#### Compact Asset Browser Dock

- **Engine-Pipeline Browser**: Asset browser dock (right side by default) whose thumbnails come from the engine's own
  `EditorResourcePreview` pipeline (same cache as the FileSystem dock - no custom thumbnail system)
  - Folder filter with native folder picker dialog, refresh, and live search
  - Grouped tree layout: subfolders become collapsible group headers (native
    tree, folders first and alphabetical); the old flat grid view was removed
  - Dock default moved to the right side (tab next to the Inspector); Godot's saved
    editor layout keeps overriding the default once the dock was placed manually
  - Native drag-and-drop using the standard `"files"` payload - the editor instantiates dropped assets itself
  - Double-click places assets on the ground plane under the mouse, with full undo support
  - Files: `addons/simpleassetplacer/ui/asset_dock.gd`, `addons/simpleassetplacer/plugin.gd`

### ⚡ Removed in 3.0

Everything beyond the two core features: placement modes and state machine, custom thumbnail pipeline,
MeshLibrary support, pickup mode, context menus, overlays, and the custom settings UI. Keep 2.x enabled
if you need those.

---

## [Unreleased]

### ✨ New Features

#### Scene Tree Context Menu Enhancements

- **Transform Node Context Menu**: Quick access to transform mode from Scene Tree
  - Right-click any Node3D object(s) in Scene Tree → "Transform Node"
  - Instantly enters transform mode for selected nodes
  - Works with single or multiple selected Node3D objects
  - Alternative to TAB keyboard shortcut for activating transform mode
  - Files: `context_menu/scene_tree_context_menu.gd`, `simpleassetplacer.gd`

#### Pickup for Placement

- **Pick Up Scene Nodes for Placement**: Select existing Node3D objects and enter placement mode to place copies
  - **Keyboard Shortcut**: Press `SHIFT+TAB` to pick up selected nodes
  - **Context Menu**: Right-click Node3D objects in Scene Tree → "Pickup for Placement"
  - **Multi-Node Support**: Pick up multiple nodes simultaneously as a group
  - **Smart Pivot**: Container origin automatically centered on selection for intuitive rotation/movement
  - **Non-Destructive**: Original nodes remain in place, only copies are placed
  - **Full Transform Support**: Rotate, scale, and position picked-up nodes like regular assets
  - **Preview Accuracy**: Placed nodes exactly match preview transforms (WYSIWYG)
  - **Clean Scene Tree**: Wrapper container automatically removed, only actual nodes placed
  - **Unique Naming**: Automatically generates readable unique names (e.g., `building_a2`, `building_a3`)
  - **Universal Compatibility**: Works with any Node3D type (MeshInstance3D, StaticBody3D, scenes, etc.)
  - Files: `utils/pickup_handler.gd`, `context_menu/scene_tree_context_menu.gd`, `simpleassetplacer.gd`, `core/placement_mode_controller.gd`

---

## [2.1.0] - 2025-10-31

### ✨ New Features

#### Parent Placement Control System

- **Flexible Parent Node Placement**
  - New parent placement modes: `root`, `selected`, `custom`, and `auto`
  - `root` mode: Place assets as children of scene root (default behavior)
  - `selected` mode: Place assets as children of currently selected node
  - `custom` mode: Place assets at a custom node path (e.g., `World/Objects`)
  - `auto` mode: Automatically create/reuse a container node for organized asset management
  - Setting: `parent_placement_mode` in Basic settings section
  - File: `utils/plugin_constants.gd`, `settings/settings_definition.gd`

- **Scene Tree Context Menu Integration**
  - Right-click any node in the Scene Tree to set it as the target parent for asset placement
  - "Set as Asset Placement Parent" context menu option
  - Visual feedback when parent is set
  - Automatically updates placement settings to use selected mode
  - File: `context_menu/scene_tree_context_menu.gd`

- **Conditional Settings UI**
  - Settings can now depend on other settings for visibility
  - `custom_parent_path` field only shown when parent mode is set to `custom`
  - `auto_parent_name` field only shown when parent mode is set to `auto`
  - Improved UX by hiding irrelevant settings
  - Enhanced `SettingMeta` class with `depends_on` and `depends_on_value` properties
  - Files: `settings/settings_definition.gd`, `settings/settings_ui_builder.gd`

- **Node Path Browser for Custom Parent**
  - Browse button (`...`) next to custom parent path field
  - Select any node from scene tree to set as custom parent
  - Real-time validation with visual feedback (✓ valid / ⚠ not found)
  - Tooltips show current validation status
  - File: `settings/settings_ui_builder.gd`

### 🎯 Improvements

#### Enhanced Placement System

- **Consistent Parent Node Handling**
  - Placement mode now determines and stores target parent node upfront
  - Eliminates inconsistencies during batch placement operations
  - Parent node cached for entire placement session
  - Applies to both asset and MeshLibrary placement
  - Files: `core/placement_mode_controller.gd`, `managers/utility_manager.gd`

- **Improved Utility Manager API**
  - New `get_target_parent_node()` method for retrieving parent based on settings
  - New `get_selected_scene_node()` method for getting selected node from editor
  - Enhanced `place_asset_in_scene()` and `place_from_meshlib()` with `stored_parent` parameter
  - Better documentation with comprehensive docstrings
  - File: `managers/utility_manager.gd`

- **Robust Physics Space State Retrieval**
  - Enhanced `get_world_space_state_static()` to work with any node type
  - Automatically searches for Node3D in hierarchy if needed
  - Falls back to viewport's World3D when direct access unavailable
  - Better handling of 2D root nodes and complex scene structures
  - New `_find_node_3d_recursive()` helper for Node3D discovery
  - File: `placement/placement_strategy.gd`

- **Settings Persistence Improvements**
  - Added support for `STRING` type settings in UI update/read operations
  - Dynamic visibility updates when parent option button changes
  - Better integration between settings definitions and UI
  - Files: `settings/settings_persistence.gd`, `settings/settings_ui_builder.gd`

- **Toolbar Settings Refresh**
  - New `_refresh_active_mode_settings()` method for immediate settings updates
  - Toolbar button changes now instantly update active placement/transform mode
  - Grid snap, random rotation, surface align, smooth transforms, and cursor warp all refresh immediately
  - Better user feedback when toggling settings during active operations
  - File: `ui/toolbar_buttons.gd`

### 🐛 Bug Fixes

- **Fixed Node Validation**
  - `NodeUtils.is_valid()` now handles freed object references gracefully
  - Parameter changed to untyped to avoid errors with freed objects
  - Added proper instance validity check before type checking
  - Prevents crashes when validating nodes that have been freed
  - File: `utils/node_utils.gd`

---

## [2.0.2] - 2025-10-27

### 🐛 Bug Fixes

#### Critical Godot 4.x Compatibility Fixes

- **Fixed crash with non-Node3D scene roots**
  - Added type check in `placement_strategy.gd` before calling `get_world_3d()`
  - Now shows clear warning message instead of crashing when scene root is not a Node3D
  - Prevents "Nonexistent function 'get_world_3d'" errors

- **Fixed AABB transformation errors**
  - Replaced deprecated `AABB.transformed()` method calls with Godot 4.x compatible implementation
  - Added `_transform_aabb()` helper function that manually transforms all 8 corners
  - Fixed "Nonexistent function 'transformed' in base 'AABB'" errors in `position_manager.gd` and `preview_manager.gd`

- **Improved error messages**
  - Physics space state warnings now provide clearer context
  - Better handling of edge cases with unusual scene structures

## [2.0.1] - 2025-10-27

### 🐛 Bug Fixes

#### Collision-Based Placement System Overhaul

- **Fixed surface offset calculation for all orientations**
  - Completely rewrote `_apply_surface_offset()` to properly account for pivot points, rotation, and scale
  - Objects now correctly sit ON floors (+Y), attach to walls (±X, ±Z), and hang from ceilings (-Y)
  - Calculates all 8 bounding box corners, transforms them by rotation/scale, and projects onto surface normal
  - Handles both simple meshes and complex PackedScenes with multiple children
  - Fixes issues where objects would clip through surfaces at different angles

- **Fixed Transform Mode surface collision**
  - Surface offset now works correctly in Transform Mode by using actual scene nodes instead of preview
  - Gets bounds and transforms from the transform target node directly
  - No more clipping when moving existing objects in the scene

- **Prevented position updates during camera navigation**
  - Added right mouse button detection in `input_processor.gd`
  - Position no longer jumps or changes when right-clicking to fly around the viewport
  - Manual position offsets are preserved correctly during camera movement

- **Removed broken directional snapping system**
  - Eliminated 235+ lines of flawed "directional snapping" logic that caused unpredictable placement
  - Replaced with standard grid snapping applied to final position (collision point + surface offset)
  - Objects now align predictably with grid lines on all surface orientations
  - Grid snapping respects both surface contact AND grid alignment

### 🎯 Improvements

- **Enhanced bounds calculation for complex hierarchies**
  - New recursive bounds gathering for PackedScenes with multiple MeshInstance3D children
  - Uses Godot's built-in `VisualInstance3D.get_aabb()` for reliable bounds detection
  - Properly accumulates transforms through node hierarchy

---

## [2.0.0] - 2025-10-26

### 🏗️ Major Architecture Refactor

**BREAKING CHANGES**: Internal architecture has been completely refactored. This is primarily an internal restructuring - the plugin API and user-facing features remain the same. However, any custom scripts or extensions that directly accessed internal manager classes will need updates.

#### Service Registry Pattern

- **Introduced ServiceRegistry for Dependency Injection**: New centralized service container pattern
  - Replaced global static managers with instance-based architecture
  - All manager instances now held in `ServiceRegistry` container
  - Created `ServiceRegistryBuilder` for clean initialization
  - Eliminates global state and improves testability
  - Files: `core/service_registry.gd`, `core/service_registry_builder.gd`

#### Command Pattern for Transform Operations

- **Transform Command System**: New command pattern for input handling
  - Introduced `TransformCommand` data object for transform operations
  - Captures position, rotation, and scale deltas in single frame
  - Supports multiple input sources with precedence rules
  - Enables cleaner separation between input and execution
  - File: `core/transform_command.gd`

#### Controller Pattern Separation

- **Split TransformationManager into Focused Controllers**: Refactored 1,610-line god object
  - `TransformationCoordinator` (~450 lines): Delegates to specialized controllers
  - `PlacementModeController`: Handles placement mode logic
  - `TransformModeController`: Handles transform mode logic  
  - `InputProcessor`: Unified input handling across modes
  - `ModeStateMachine`: Centralized mode state management
  - Files: `core/transformation_coordinator.gd`, `core/*_controller.gd`, `core/mode_state_machine.gd`

#### Input System Refinement

- **Structured Input State Classes**: New input state hierarchy
  - `RawInputSnapshot`: Captures raw input with tap detection
  - Specialized state classes: `PositionInputState`, `RotationInputState`, `ScaleInputState`
  - `ControlModeInputState`: Handles axis constraints (X/Y/Z keys)
  - `NavigationInputState`: Handles camera input filtering
  - Files: `managers/input/*.gd`

#### Manager Organization

- **Relocated Core Managers**: Moved managers from `core/` to `managers/` directory
  - `PositionManager`: `core/` → `managers/`
  - `RotationManager`: `core/` → `managers/`
  - `ScaleManager`: `core/` → `managers/`
  - `SmoothTransformManager`: `core/` → `managers/`
  - Created `GridManager` for grid operations
  - Better separation of concerns and logical grouping

#### Utility Extraction

- **New Utility Classes**: Extracted reusable components
  - `AxisOperationsHelper`: Axis-constrained transform operations
  - `CursorWarpAdapter`: Testable cursor warping logic
  - `TransformMath`: Mathematical transform utilities
  - `NodeUtils`: Node tree manipulation helpers
  - `LayoutCalculator`: UI layout calculations
  - `UndoRedoHelper`: Undo/redo operation wrapper
  - Files: `utils/*.gd`

#### Settings System Improvements

- **Enhanced Settings Architecture**: Better separation and validation
  - `SettingsStorage`: Handles settings persistence
  - `SettingsValidator`: Validates setting values
  - Improved `SettingsManager` with cleaner API
  - Better error handling and logging

#### Placement Strategy Refactor

- **Renamed PlacementStrategyManager**: Better naming consistency
  - `PlacementStrategyManager` → `PlacementStrategyService`
  - Consistent with service-oriented architecture
  - File: `placement/placement_strategy_service.gd`

### ✨ New Features

#### Cursor Warping Enhancement

- **Cursor Warp Toggle**: New toolbar button for cursor warping
  - Toggle cursor warping during mouse-driven transforms
  - Visual indicator in toolbar
  - Setting: `cursor_warp_enabled`
  - File: `ui/toolbar_buttons.gd`

#### About Tab

- **New About Tab UI**: Plugin information and credits
  - Shows version, author, and links
  - First-time visibility flag
  - File: `ui/about_tab.gd`

### 🐛 Bug Fixes

#### Removed Legacy Code

- **Cleaned Up Backup Files**: Removed leftover backup files
  - Deleted `core/transformation_coordinator.gd.backup`
  - Deleted `ui/status_overlay.tscn.backup`

### 📝 Documentation

#### Code Documentation

- **Comprehensive Inline Documentation**: Added detailed docstrings
  - Every class now has PURPOSE, RESPONSIBILITIES, and ARCHITECTURE sections
  - Clear dependency documentation (USED BY / USES)
  - Improved code navigation and understanding
  - Consistent documentation format across all files

#### Updated README

- **Restructured README**: More accurate feature documentation
  - Added source file references for all features
  - Verified against actual codebase
  - Better organization of feature sections
  - File: `README.md`

### ⚙️ Technical Improvements

#### Dependency Management

- **Explicit Dependency Injection**: All managers receive dependencies via constructor
  - No more hidden global dependencies
  - Clear service relationships
  - Easier to test and mock

#### Error Handling

- **Improved Error Handling**: Better error recovery and logging
  - Safe cleanup with `_safe_cleanup()` wrapper
  - Graceful degradation on errors
  - More informative error messages

#### Code Organization

- **Better File Structure**: Logical grouping of related functionality
  - `core/` - Core state and coordination
  - `managers/` - Specialized managers
  - `placement/` - Placement strategies
  - `settings/` - Settings management
  - `ui/` - User interface
  - `utils/` - Shared utilities
  - `thumbnails/` - Thumbnail generation
  - `tests/` - Unit tests

### 🔧 Migration Notes

#### For Plugin Users

- **No Action Required**: All user-facing features work identically
- Settings and preferences are preserved
- Keyboard shortcuts unchanged
- UI and workflow remain the same

#### For Extension Developers

If you have custom scripts that access plugin internals:

**Manager Access Changes:**

```gdscript
# OLD (static global access)
SettingsManager.get_setting("key")
PositionManager.configure(settings)
TransformationManager.start_placement_mode(...)

# NEW (instance-based via plugin)
var plugin = EditorPlugin.get_editor_interface().get_plugin("SimpleAssetPlacer")
var registry = plugin.service_registry
registry.settings_manager.get_setting("key")
registry.position_manager.configure(settings)
registry.transformation_coordinator.start_placement_mode(...)
```

**Renamed Classes:**

- `PlacementStrategyManager` → `PlacementStrategyService`
- `TransformationManager` → `TransformationCoordinator`

**Moved Files:**

- `core/position_manager.gd` → `managers/position_manager.gd`
- `core/rotation_manager.gd` → `managers/rotation_manager.gd`
- `core/scale_manager.gd` → `managers/scale_manager.gd`
- `core/smooth_transform_manager.gd` → `managers/smooth_transform_manager.gd`

## [1.4.1] - 2025-10-11

### 🐛 Bug Fixes

#### Scale and Transform Fixes

- **Fixed Smooth Transforms Scale Application**: Assets now placed with correct scale when smooth transforms enabled
  - Preview manager now returns target transforms instead of mid-lerp values
  - Added `get_target_rotation()` method to SmoothTransformManager
  - Newly placed objects use `apply_transform_immediately()` to prevent lerp interference
  - Resolves issue where 120% scaled assets were placed at 100%

- **Changed Scale System to Additive**: Transform mode now uses additive scaling instead of multiplicative
  - Formula changed from `final = original × multiplier` to `final = original + offset`
  - Allows symmetric stepping: increase by 0.2 then decrease by 0.2 returns to original scale
  - Fixed issue where transforming 1.2 scale asset would land on 0.96 instead of 1.0
  - Added floating point rounding (snappedf to 0.001) to prevent 0.999999 values

#### Tag Management Dialog Fixes

- **Fixed "Manage Tags" Dialog Compatibility**: Dialog now works with both asset browsers
  - Added `_get_asset_identifier()` helper to handle different asset structures
  - Regular assets use 'path' key, meshlib items use 'meshlib_path:name' format
  - Added `_get_asset_display_name()` for consistent name display
  - Fixes "Invalid access to property 'path'" errors when opening from meshlib browser

## [1.4.0] - 2025-10-09

### ✨ New Features

#### Quick Action Toolbar Enhancements

- **Transform Mode Button** (🔧): Added dedicated toolbar button for transform mode
  - Toggle button with visual feedback when active
  - Displays configured keyboard shortcut in tooltip (default: TAB)
  - Button state automatically syncs with keyboard shortcut
  - Requires selected Node3D objects to activate
  
- **Reset All Transforms Button** (↺): One-click reset for all transform offsets
  - Clears position, rotation, scale, and height offsets instantly
  - Works in both Placement and Transform modes
  
- **Dynamic Keybind Tooltips**: All toolbar buttons now show actual configured keybinds
  - Automatically updates when settings change
  - Reads directly from settings for immediate consistency
  - Eliminates confusion from hardcoded hints

#### Keyboard Confirmation

- **Configurable Confirmation Key**: Added keyboard shortcut for confirming placements/transformations
  - Default: Enter key (customizable in Settings → Control Keys)
  - Works alongside left mouse click
  - Confirms asset placement and transformations
  - Settings persist across sessions

#### Visual Enhancements

- **Placement Strategy Indicator**: On-screen overlay shows active placement mode
  - 🎯 Collision icon for raycast placement
  - 📐 Plane icon for horizontal plane projection
  - Updates in real-time when switching strategies
  
- **Half-Step Grid Visualization**: Visual feedback for fine increment snapping
  - Red half-step grid appears when fine increment modifier (CTRL) is held
  - Shows grid at 50% of normal spacing
  - Semi-transparent overlay above main grid

### 🎨 UI/UX Improvements

#### Toolbar Integration

- **Quick Actions Moved to Viewport Toolbar**: Buttons relocated from overlay to 3D viewport menu
  - Appears in `CONTAINER_SPATIAL_EDITOR_MENU` next to Transform/View tools
  - Icon-only format (71% space reduction: 440px → 128px)
  - **6 Toolbar Buttons**:
    - 🎯 Placement Mode (cycles Collision ↔ Plane, icon changes)
    - 📏 Grid Snap
    - 🔲 Grid Overlay
    - 🔄 Random Rotation
    - 🔧 Transform Mode
    - ↺ Reset All
  - Matches Godot's native toolbar aesthetic
  - Two-way sync with settings panel

#### Status Overlay Redesign

- **Compact Layout**: Restructured with organized information hierarchy
  - Title Row: Mode label + Node name + Strategy indicator
  - Transform Row: Color-coded Position | Rotation | Scale (with VSeparator dividers)
  - Keybinds Row: Context-sensitive control hints
  - Size reduced: 800×120px → 700×100px (27% smaller)
  - Mouse filter set to `IGNORE` (display-only)

### 🏗️ Architecture Improvements

#### Directory Reorganization

- **Logical Folder Structure**: Organized 33 files into 7 subdirectories
  - `core/` - Transform & state management (7 files)
  - `placement/` - Strategy pattern system (4 files)
  - `ui/` - User interface components (6 files)
  - `settings/` - Settings management (4 files)
  - `managers/` - Supporting managers (5 files)
  - `thumbnails/` - Thumbnail generation (3 files)
  - `utils/` - Utilities & helpers (4 files)
  - Updated 100+ import paths

#### State Management Refactor

- **Stateless Design Pattern**: Eliminated scattered static variables
  - **TransformState**: Unified container for all transform state (237 lines)
  - **TransformApplicator**: Centralized transform application (238 lines)
  - **PositionManager**, **RotationManager**, **ScaleManager**: Refactored to stateless
    - All methods now accept `TransformState` as parameter
    - 48% reduction in state management complexity
    - Single source of truth for transform data
    - Improved testability (pure functions)

#### Placement Strategy Pattern

- **Strategy-Based Architecture**: Clean separation of placement modes
  - Base `PlacementStrategy` class with `CollisionPlacementStrategy` and `PlanePlacementStrategy`
  - `PlacementStrategyManager` coordinates strategy selection
  - Reduced `PositionManager.update_position_from_mouse()` from 100+ to ~40 lines
  - 60% reduction in positioning logic complexity

#### Settings System Refactor

- **Data-Driven Architecture**: 86% reduction in settings code
  - **SettingsDefinition**: Single source of truth for metadata (229 lines)
  - **SettingsUIBuilder**: Automated UI generation (234 lines)
  - **SettingsPersistence**: Centralized save/load (109 lines)
  - Reduced from 2,178 to 301 lines in main settings file
  - Adding new settings now requires only 1 line instead of 15+

### 🔧 Improvements

- **Collision Exclusion System**: Preview meshes no longer interfere with placement raycasts
  - Recursively gathers collision RIDs from nodes
  - **Note**: CSG nodes cannot be excluded (Godot 4 engine limitation)
  
- **Placement Mode Switching**: Press `P` to cycle Collision ↔ Plane modes
  - Works in both placement and transform modes
  - Visual feedback via overlay
  
- **Increment Calculator**: Unified step calculations with modifier support
  - Consistent scaling across rotation, scale, position, height
  - Configurable multipliers (default: 5x large, 0.1x fine)

### 🐛 Bug Fixes

- Fixed toolbar buttons not reflecting saved settings on load
- Fixed VSeparator2 parent path typo in status_overlay.tscn
- Fixed tooltip lag when updating keybinds in settings
- Fixed placement mode icon not syncing with keyboard shortcut (P key)
- Fixed overlay collision detection blocking viewport clicks
- Fixed duplicate strategy logging on mode entry
- Fixed position offsets not persisting between placement/transform modes
- Fixed objects jumping when entering transform mode
- Fixed rotation/scale increments not using configured values

### 📁 Technical Changes

**New Files:**

- `core/transform_state.gd` - Unified transform state container
- `core/transform_applicator.gd` - Centralized transform application
- `core/smooth_transform_manager.gd` - Interpolation system
- `placement/placement_strategy.gd` - Base strategy class
- `placement/collision_placement_strategy.gd` - Raycast placement
- `placement/plane_placement_strategy.gd` - Plane projection
- `placement/placement_strategy_manager.gd` - Strategy coordinator
- `settings/settings_definition.gd` - Settings metadata
- `settings/settings_ui_builder.gd` - Automated UI generation
- `settings/settings_persistence.gd` - Save/load operations
- `ui/toolbar_buttons.tscn` - Toolbar button scene
- `ui/toolbar_buttons.gd` - Toolbar controller
- `ui/status_overlay.tscn` - Status overlay scene
- `ui/status_overlay_control.gd` - Status overlay controller
- `utils/increment_calculator.gd` - Increment calculations

**Reorganized Files:**

- Moved all managers to respective folders (core/, managers/, etc.)
- Updated 100+ import paths across codebase

---

## [1.3.2] - 2025-10-05

### 🐛 Fixed

- **Orphaned Tag Data**: Tag system now automatically cleans up data for deleted assets
  - Tags, favorites, and recent assets for deleted files are automatically removed
  - Cleanup runs automatically when plugin loads or when refresh button is clicked
  - Tag usage statistics are recalculated after cleanup
  - Prevents stale references and keeps `.assetcategories` file clean
- **Position Reset on Large Rotation**: Fixed position getting reset unexpectedly after rotating with large increments
  - Increased XZ distance threshold from 0.01 to 0.1 units in position change detection
  - Prevents tiny mouse movements during rotation from triggering false position updates
  - Asset position now remains stable when rotating with 90° or other large increments
- **Grid Offset Snapping**: Fixed grid offset not being applied to snapping calculations
  - Grid offset spinbox controls are now properly stored as class member variables (`grid_offset_x_spin`, `grid_offset_z_spin`)
  - Fixed `_on_grid_setting_changed()` callback to access spinbox values using member variables instead of failing node path lookups
  - Grid offset values now correctly update the `snap_offset` variable when changed in the UI
  - Snapping now properly offsets from world origin (e.g., 0.5 offset results in snapping to -6.5, -1.5 instead of -6.0, -1.0)
- **Grid Offset Settings Persistence**: Fixed grid offset values not loading on plugin startup
  - Added `update_ui_from_settings()` call in `_ready()` to apply loaded settings to UI controls
  - Updated `update_ui_from_settings()` to use member variable references for grid offset spinboxes
  - Grid offset values now persist correctly across Godot sessions
- **Settings System**: Fixed critical issues with settings not being saved or loaded correctly
  - Connected all missing signal handlers for grid controls (8 controls)
  - Connected all missing signal handlers for position increment controls (3 controls)
  - Added `_on_grid_setting_changed()` handler for grid extent, Y-axis snapping, center snapping, and grid offset controls
  - Added `_on_position_increment_changed()` handler for position increment spinboxes
  - Updated `save_settings()` to save all grid settings (grid_extent, snap_center_x/y/z, position increments)
  - Updated `load_settings()` to load all grid settings with proper defaults
  - Enhanced `_disconnect_ui_signals()` and `_connect_ui_signals()` to properly handle grid and position controls
  - Fixed initial values for grid controls to use actual settings instead of hardcoded defaults
  - All 11 previously unconnected controls now properly save/load their values

### 🔧 Improved

- **Settings Persistence**: All placement settings now correctly persist across Godot sessions
  - Grid display size setting now saves/loads properly
  - Y-axis snapping settings (enabled and step size) now persist
  - Grid center snapping options (X/Y/Z) now save/load correctly
  - Grid offset values (X/Z) now persist properly and update UI on load
  - Position increment values (normal/fine/large) now save/load correctly
  - UI controls now display loaded values on startup

## [1.3.1] - 2025-10-05

### 🐛 Fixed

- **Critical Runtime Error**: Fixed missing `fine_increment_modifier_held` key in rotation and scale input dictionaries
  - Added `fine_increment_modifier_held` to `get_rotation_input()` function
  - Added `fine_increment_modifier_held` to `get_scale_input()` function
  - Eliminated hundreds of runtime errors when using rotation or scale transformations
  - Ensures consistent modifier key structure across all input query functions

### 🏗️ Technical Improvements

- **Code Cleanup**: Removed deprecated helper functions (`is_shift_held()`, `is_ctrl_held()`, `is_alt_held()`) from input dictionaries
  - All input now uses configurable modifier system (`reverse_modifier_held`, `large_increment_modifier_held`, `fine_increment_modifier_held`)

## [1.3.0] - 2025-10-05

### ✨ New Features

#### Hold-to-Repeat System

- **Continuous Actions While Holding Keys**: Hold transformation keys to repeatedly apply actions
  - **Grace Period**: 150ms delay before repeat starts (preserves tap behavior for mouse wheel combos)
  - **Smart Repeat Intervals**: Optimized for each action type
    - Rotation: 100ms (responsive rotation)
    - Scale: 80ms (smooth scaling)
    - Height: 80ms (smooth vertical adjustment)
    - Position: 50ms (smooth WASD movement)
  - **Supported Keys**: Works with all transformation keys (X/Y/Z rotation, Q/E height, WASD position, PageUp/Down scale)
  - **Single Action Priority**: Only one action repeats at a time (pressing new key cancels previous)
  - **Modifier Change Detection**: Pressing/releasing SHIFT or ALT during repeat cancels it
  - **Wheel Interruption**: Using mouse wheel interrupts repeat and requires key re-press
  - **Tap Behavior Preserved**: Quick press (< 150ms) still performs single action for wheel combos

### 🐛 Fixed

- **Grid Overlay Coordinate System**: Fixed grid overlay moving in opposite direction when transforming nodes
  - Root cause: Grid was inheriting flipped coordinate system from scene root nodes with 180° Y-axis rotation
  - Solution: Set `top_level = true` on grid overlay to make it independent of parent transform
  - Grid now works correctly regardless of scene root rotation or transform
  - Both XZ plane movement and Y-axis height adjustments now follow object correctly
- **Random Y-Rotation Now Works**: Fixed broken random rotation feature - settings were being passed but never applied during placement
  - Added random rotation application in `utility_manager.gd` for all three placement functions (place_asset_in_scene, place_meshlib_item_in_scene, place_mesh_in_scene)
  - Random rotation now applies AFTER manual rotation offsets, giving full 0-360 degree randomization on Y-axis
- **Hardcoded Modifier Keys**: Fixed all remaining hardcoded CTRL/SHIFT/ALT key references
  - Added new configurable `fine_increment_modifier_key` setting (default: CTRL)
  - Removed all hardcoded `ctrl_held` checks throughout codebase
  - TransformationManager now uses `fine_increment_modifier_held` for grid snapping half-step mode
  - Updated fine increment detection for height adjustments (placement and transform modes)
  - Updated fine increment detection for WASD position adjustments (placement and transform modes)
  - Updated rotation increment logic to use `fine_increment_modifier_held` instead of hardcoded CTRL
  - All modifier keys now fully configurable: Reverse Direction, Large Increment, and Fine Increment
  - Users can now bind all modifiers to any key combination

### 🏗️ Technical Improvements

- **InputHandler Enhancements**:
  - Added `is_action_key_held_with_repeat()` function with comprehensive state tracking
  - New tracking variables: `active_repeat_key`, `active_repeat_modifiers`, `wheel_interrupted_keys`, `repeat_intervals`
  - Modifier tracking now uses all three configured modifier keys (`reverse_modifier_key`, `large_increment_modifier_key`, `fine_increment_modifier_key`)
  - Added `is_fine_increment_modifier_held()` helper function for half-step detection
  - Wheel interruption detection automatically flags held keys when wheel is used
  - Automatic cleanup on key release (clears interruption flags and repeat state)
- **Input Query Functions Updated**:
  - `get_rotation_input()`: X/Y/Z keys support hold-to-repeat
  - `get_scale_input()`: PageUp/Down keys support hold-to-repeat
  - `get_position_input()`: Q/E (height) and WASD (position) keys support hold-to-repeat, added `fine_increment_modifier_held` field
- **Settings System**:
  - Added "Fine Increment" modifier key configuration in Settings → Modifier Keys
  - All three modifier keys now fully configurable: Reverse Direction (SHIFT), Large Increment (ALT), Fine Increment (CTRL)
  - UI controls for fine increment modifier key binding with key capture support
  - Settings persist across sessions via EditorSettings

---

## [1.2.1] - 2025-10-04

### 🐛 Fixed

- **Pure Modifier Key Bindings**: Fixed support for binding pure modifiers (ALT, CTRL, SHIFT, META) to modifier keys (Large Increment, Reverse Direction)
- **Modifier-Only Combinations**: Fixed capturing modifier-only combinations like CTRL+ALT without requiring a base key
- **Key Chord Recording**: Improved key binding capture to record all pressed keys and capture complete combinations on release
- **Modifier Key Recognition**: Fixed issue where modifier keys were not being recognized during gameplay (rotation, scale, height adjustments)
- **Configurable Modifiers in Transformation Manager**: Updated all transformation logic to use configurable modifier keys instead of hardcoded SHIFT/ALT
- **Input Dictionary Completeness**: Added missing `reverse_modifier_held` field to scale input dictionary

### 🔧 Improved

- **Key Binding Capture Logic**: Redesigned to use a recording approach that tracks all pressed keys and captures on complete release
- **Action Key Detection**: Action keys (Y, X, Z, Q, E, etc.) now properly detected even when modifiers are held
- **Modifier Separation**: Modifier state checks are now independent from action key detection, allowing proper combinations like SHIFT+Y for reverse rotation

---

## [1.2.0] - 2025-10-04

### ✨ New Features

#### Asset Cycling System

- **Cycle Through Assets During Placement**: Press `]` or `[` to browse assets without leaving the viewport
  - **Next Asset**: Press `]` (BRACKETRIGHT) to cycle forward through visible assets
  - **Previous Asset**: Press `[` (BRACKETLEFT) to cycle backward through visible assets
  - **Tap to Cycle Once**: Quick press cycles to next/previous asset
  - **Hold to Rapid Cycle**: Hold key to quickly browse through multiple assets (150ms repeat rate)
  - **Context-Aware**: Cycles through currently filtered view (category, favorites, search results, tags)
  - **Auto-Scroll**: Browser automatically scrolls to keep selected asset visible
  - **Visual Feedback**: Thumbnail highlights and preview updates instantly
  - **Works with Both Tabs**: Supports 3D Models and MeshLibrary browsers
  - **Wrap-Around**: Seamlessly loops from last asset back to first

#### Cycling Configuration

- Added "Cycle Next Asset" keybind in Settings → Control Keys
- Added "Cycle Previous Asset" keybind in Settings → Control Keys
- Fully customizable key assignments
- Settings persist across Godot sessions

### 🌍 Enhanced - Universal Keyboard Layout Support

#### International Keyboard Compatibility

- **ALL keybinds now support modifier combinations** (CTRL+ALT+8, SHIFT+X, etc.)
  - Rotation keys (X, Y, Z, Reset)
  - Scale keys (Page Up, Page Down, Home)
  - Height adjustment keys (Q, E, R)
  - Position keys (W, A, S, D, G)
  - Control keys (TAB, ESC)
  - Asset cycling keys (], [)

#### Modifier Combination Support

- **Full chord detection**: Press CTRL+ALT+8 to configure keybinds requiring modifiers
- **Conflict prevention**: Simple key bindings won't trigger when modifiers are held
- **Exact matching**: Each keybind checks for precise modifier state
- **Number key fallback**: Automatic conversion for keyboards requiring modifiers for numbers
- **Works with all modifiers**: CTRL, ALT, SHIFT, META (Windows/Command key)

#### Keybind Capture Improvements

- Settings UI now properly captures modifier combinations
- Ignores standalone modifier key presses (waits for actual key)
- Displays full key combination in settings (e.g., "CTRL+ALT+9")
- Visual feedback during key capture
- ESC to cancel key binding

### 🐛 Fixed

- **Keybind capture bug**: Settings now correctly captures full modifier combinations instead of first key pressed
- **Modifier isolation**: Modifiers no longer interfere with simple key bindings
- **International layouts**: Keyboards requiring modifiers for brackets/special chars now work properly

### 🏗️ Technical Improvements

- New `InputHandler._check_key_with_modifiers()` - Universal modifier detection
- Enhanced input state tracking for tap vs hold detection
- `ModelLibraryBrowser.cycle_to_next_asset()` - Cycles through 3D models
- `ModelLibraryBrowser.cycle_to_previous_asset()` - Reverse cycling for models
- `MeshLibraryBrowser.cycle_to_next_item()` - Cycles through meshlib items
- `MeshLibraryBrowser.cycle_to_previous_item()` - Reverse cycling for meshlib
- `AssetPlacerDock.cycle_next_asset()` - Tab-aware cycling coordinator
- `AssetPlacerDock.cycle_previous_asset()` - Reverse coordinator
- `TransformationManager._process_asset_cycling_input()` - Placement mode integration
- Auto-scroll implementation for browser visibility management

### 🎯 Workflow Enhancements

- Stay in creative flow - no need to return to dock during placement
- Quick asset iteration for level design
- Visual comparison by rapidly cycling between options
- One-handed operation (place with mouse, cycle with keyboard)
- Works seamlessly with existing filtering and search features

---

## [1.1.1] - 2025-10-04

### 🔧 Architecture & Bug Fixes

#### Offset-Based Architecture Refactor

- **RotationManager**: Complete refactor to use offset-based system instead of absolute rotations
  - Renamed `current_rotation` → `manual_rotation_offset` (breaking change for internal API)
  - Renamed `set_rotation()` → `set_rotation_offset()`
  - Now preserves original node rotations when entering transform mode
  - Rotation formula: `final_rotation = original_rotation + surface_alignment + manual_offset`
  
- **ScaleManager**: Complete refactor to use multiplier-based system instead of absolute scales
  - Renamed `current_scale` → `scale_multiplier` (breaking change for internal API)
  - Renamed `non_uniform_scale` → `non_uniform_multiplier`
  - Now preserves original node scales when entering transform mode
  - Scale formula: `final_scale = original_scale * scale_multiplier`

#### Transform Mode Improvements

- **Fixed critical bug**: Node rotations no longer reset to zero when entering transform mode with multiple nodes
- **Group rotation**: Implemented rotation around collective center while preserving individual node rotations
- **Position updates**: Eliminated `initial_frame` workaround for cleaner logic
- **Original transforms**: All original transforms (position, rotation, scale) now stored in `original_transforms` dictionary at mode start
- Unified transform application flow with consistent offset-based approach

#### Visual Improvements

- **Thumbnail camera angle**: Adjusted from `Vector3(1, 0.7, 1)` to `Vector3(1, 1, -1)` (frontal-diagonal view)
- Increased camera padding from 1.5x to 2x for better framing
- Thumbnails now show frontal view of assets for better preview quality and identification

#### Stability & Compatibility

- **Removed Terrain3D plugin**: Completely removed Terrain3D addon to prevent conflicts
  - Deleted 169 files including binaries, brushes, icons, tools, and utilities
  - Cleaned up sample scenes and terrain data
  - Updated `project.godot` to disable terrain_3d plugin
- Added Terrain3D usage tip in README for users who want to use it separately

### 🏗️ Technical Improvements

- **Unified architecture**: All transformation managers now use consistent offset-based calculations
- **Better encapsulation**: Original node values preserved and never directly modified
- **Cleaner code**: Removed workarounds and simplified logic flows
- **Improved maintainability**: Consistent naming conventions across all managers
- **Better separation of concerns**: Clear distinction between original values, offsets, and final transforms

---

## [1.1.0] - 2025-10-04

### 🎉 Major Features

#### Grid Snapping System

- Added comprehensive grid snapping functionality to position management
- Implemented center snapping options for X, Y, and Z axes independently
- Added grid overlay visualization with dynamic updates based on object movement
- Grid overlay now tracks height changes and responds to vertical movements
- Enhanced snapping features with improved position adjustment logic

#### Surface Normal Alignment

- Added alignment with surface normal feature for object rotation
- Implemented Y position handling with surface normal alignment
- Enhanced clipping prevention with improved surface alignment
- Added surface alignment reset functionality in rotation management

#### Position Management Overhaul

- Complete refactor of position management system
- Added initial position tracking and Y-axis locking functionality
- Implemented base position retrieval for ground-level placement
- Enhanced collision detection based on snap_to_ground setting
- Improved Y position adjustment logic with transformation enhancements
- Added manual position offset with proper state handling
- Height offset now properly saved when switching assets

#### Transform Mode Enhancement

- Multi-node transformation support - apply adjustments to all target nodes
- Enhanced height, scale, and rotation adjustments for multiple objects
- Improved height adjustment handling with fine increments in placement mode
- Added incremental adjustments based on modifier keys (Shift for fine control)
- Refactored to use unified TransformationManager.Mode for mode handling

#### Height Adjustment System

- Comprehensive height adjustment system with reset functionality
- Added reset height button and UI controls
- Implemented "Reset All Settings" button with confirmation dialog
- Enhanced height offset management with simplified logic
- Improved signal connections for height adjustment controls
- Height offset properly persists when switching between assets

#### Asset Management Improvements

- Added "Ignore Asset" functionality to filter unwanted assets
- Improved thumbnail generation with async request handling
- Enhanced thumbnail generation for scene files (.tscn)
- Thumbnail generator now retains cached thumbnails across panel visibility changes
- Added neutral material override for better visibility while preserving asset materials
- Async asset filtering and processing

#### Settings & Preferences

- Implemented last selected mesh library and category restoration
- Settings now persist between sessions
- Added reset position offset option on exit
- Enhanced settings management for placement mode
- New SettingsManager for centralized configuration handling

### 🔧 Major Refactoring

#### Plugin Architecture Refactor

- Created modular plugin architecture with specialized managers:
  - **AssetScanner**: Handles asset discovery and scanning
  - **ErrorHandler**: Centralized error handling and reporting
  - **PluginConstants**: Shared constants and configuration
  - **PluginLogger**: Structured logging system
  - **SettingsManager**: User preferences and settings persistence
- Reduced asset_placer_dock.gd complexity by 250+ lines
- Improved code maintainability and separation of concerns

#### Manager Enhancements

- **TransformationManager**: 885+ lines of improvements
  - Unified mode handling (placement/transform)
  - Better state management
  - Improved input processing configuration
- **PositionManager**: 350+ lines added
  - Enhanced collision detection
  - Improved ground snapping
  - Better height offset handling
- **OverlayManager**: 152+ lines added
  - Grid visualization
  - Dynamic overlay updates
  - Mode-aware rendering
- **RotationManager**: 114+ lines added
  - Surface normal alignment
  - Reset functionality
  - Offset adjustment support

#### Preview Management Refactor

- Preserve original materials by applying transparency instead of material overrides
- Improved preview visibility without affecting asset materials
- Better handling of preview state transitions

### 🐛 Bug Fixes

- Fixed export-ignore rules for addons in .gitattributes
- Removed debug print statements from production code
- Fixed viewport bounds checking for mouse position
- Improved state handling to prevent position reset issues
- Fixed height offset not saving when switching assets

### 🎨 UI/UX Improvements

- Added shift key detection for scaling operations
- Improved rotation display logic with better visual feedback
- Enhanced placement settings UI with more controls
- Added confirmation dialogs for destructive operations
- Better visual feedback for grid overlay
- Improved control responsiveness

### 📦 Asset Categories

- Updated asset categories with improved tagging
- Added new terrain asset support (Terrain3D integration for testing)
- Enhanced input handling for category management

### 🏗️ Sample/Demo Updates

- Added building_b scene to sample project
- Updated building scene configurations with improved transformations
- Enhanced wall and roof node transformations
- Improved demo scene references and examples

### 📝 Technical Improvements

- Better input coordinate conversion with viewport support
- Enhanced modifier key handling (Shift, Ctrl, Alt)
- Improved signal connections throughout the plugin
- Better synchronization between managers
- More robust error handling and validation
- Improved performance with optimized update logic

### 🔄 Internal Changes

- Added 611+ lines to placement_settings.gd for enhanced controls
- Enhanced thumbnail_generator.gd with 400+ lines of improvements
- Improved category_manager.gd with better tag management
- Enhanced modellib_browser.gd with 125+ lines of new features
- Better asset filtering and search capabilities

---

## Installation & Usage

This plugin helps you quickly place assets in your Godot 3D scenes with powerful transform controls, grid snapping, and asset management features.

### Breaking Changes

- v1.1.1: Internal API changes in RotationManager and ScaleManager (offset-based architecture)

### Known Issues

None currently reported

---

**Full Changelog**: https://github.com/IIFabixn/simple-asset-placer/commits/main
