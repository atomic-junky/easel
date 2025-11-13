# Tabbed Menu Interface - Feature Documentation

## Overview

The GestureApp menu has been enhanced with a step-based tabbed interface to improve user experience and navigation. This update introduces session management capabilities and a more organized workflow.

## New Features

### 1. Session Management (.gsession files)

**What changed:**
- `SessionContext` has been renamed to `SessionResource` and is now a proper Godot Resource
- Sessions can be saved as `.gsession` files and loaded later
- Session history is automatically tracked (last 10 sessions)

**Usage:**
```gdscript
# Save a session
var session := SessionResource.new()
session.save_to_file("user://my_session.gsession")

# Load a session
var loaded := SessionResource.load_from_file("user://my_session.gsession")
```

### 2. Tabbed Navigation

The menu now features three tabs for a streamlined onboarding experience:

#### Tab 1: Session Management
- **New Session** button - Start a fresh session
- **Import Session** button - Load a saved .gsession file
- **Session History** - Quick access to recently saved sessions

#### Tab 2: Pack Selection
- All existing pack import methods (Folder, Images, Pinterest, History)
- **Recent Packs** section - Quick-add buttons for frequently used packs
- Pack information display (image count, pack count)

#### Tab 3: Mode Selection
- Session type switcher (Standard, Relaxed, Class Mode, Custom)
- Mode-specific configuration panels
- **Save Session** button (💾) - Export current session as .gsession
- **Let's draw!** button - Start the drawing session

### 3. SessionHistory Autoload

A new singleton that automatically tracks saved sessions:
- Stores up to 10 recent sessions
- Persistent across app restarts
- JSON-based storage in `user://session_history/`

## Technical Implementation

### Runtime UI Restructuring

The tabbed interface is created programmatically at runtime in the `Menu._ready()` function:

1. The existing `PropertyContainer` is extracted from the scene
2. A new `TabContainer` is created and inserted in its place
3. Existing UI elements are reorganized into the appropriate tabs:
   - Session management UI is created fresh
   - Pack selection UI (VBox with SelectPackButton) moves to Tab 2
   - Mode selection UI (SessionTypeSwitcher + Panel) moves to Tab 3

This approach minimizes scene file modifications while achieving the desired interface.

### Backward Compatibility

The tabbed interface can be disabled by setting `_use_tabs = false` in `Menu.gd`, which will preserve the original single-screen layout.

## File Structure

```
autoloads/
  ├── session_history.gd          # NEW: Session history tracking
prefabs/
  ├── session_resource.gd          # RENAMED from session_context.gd
scenes/menu/
  ├── menu.gd                      # MODIFIED: Added tabbed interface logic
project.godot                      # MODIFIED: Added SessionHistory autoload
```

## Migration Notes

### For Developers

If you have code that references `SessionContext`:
- All references have been automatically updated to `SessionResource`
- The API remains the same, only the name changed
- New methods available: `save_to_file()` and `load_from_file()`

### For Users

- Existing sessions will continue to work
- Old session data is preserved
- New sessions can be saved and shared as .gsession files

## User Workflow

### Creating and Saving a Session

1. Open GestureApp menu
2. **Tab 1 (Session):** Click "New Session" to start fresh
3. **Tab 2 (Packs):** Select image packs for your session
   - Use "Select packs" button for various import options
   - Or click recent packs to quickly add them
4. **Tab 3 (Mode):** Choose your session type and configure settings
   - Click "💾 Save Session" to export for later use
5. Click "Let's draw!" to start your session

### Loading a Saved Session

1. Open GestureApp menu
2. **Tab 1 (Session):** Either:
   - Click a session from the history list, or
   - Click "Import Session" to browse for a .gsession file
3. The session will load with all packs and settings restored
4. Navigate through tabs to review/modify if needed
5. Click "Let's draw!" to start

## Benefits

1. **Better Organization:** Clear separation of workflow steps
2. **Session Persistence:** Save and reuse session configurations
3. **Quick Access:** Recently used packs and sessions are readily available
4. **Improved UX:** Step-by-step navigation reduces cognitive load
5. **Shareable:** .gsession files can be shared between users/devices

## Future Enhancements

Potential improvements that could be added:
- Drag-and-drop pack reordering in Tab 2
- Session templates/presets
- Cloud sync for session files
- Session thumbnails/previews
