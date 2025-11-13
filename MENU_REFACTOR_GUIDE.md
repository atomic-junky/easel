# Menu Refactor Implementation Guide

## Overview
This document describes how to refactor the menu to use scene-based tabs with validation, as requested in the PR comments.

## Current Issues
1. Tabs are created at runtime, should be in scene
2. No validation between tabs
3. Pack popup overlay should be integrated into tab
4. Save session button should be next to Let's draw button
5. Code is monolithic (845 lines in menu.gd)
6. Tabs don't take full horizontal space

## Implementation Plan

### Phase 1: Scene Structure (Manual in Godot Editor)

**1.1 Create TabContainer in menu.tscn:**
- Replace `PropertyContainer` with a `TabContainer` node
- Set TabContainer to `size_flags_horizontal = SIZE_EXPAND_FILL`
- Set TabContainer `tab_alignment = ALIGNMENT_CENTER` for full width tabs

**1.2 Create Tab 1 - Session:**
- Add VBoxContainer as child of TabContainer, name it "Session"
- Add HBoxContainer for buttons:
  - Button: "New Session"
  - Button: "Import Session"
- Add Label: "Previous Sessions"
- Add ScrollContainer with VBoxContainer inside for session history list

**1.3 Create Tab 2 - Packs:**
- Add VBoxContainer as child of TabContainer, name it "Packs"
- Move all pack selection UI from PackSelectorContainer into this tab:
  - Label: "Select Image Packs"
  - HFlowContainer with buttons (Folder, Images, Pinterest, History)
  - ScrollContainer with VBoxContainer for selected packs
  - Label for pack info (X images in Y packs)
- Add section for pack history:
  - Label: "Recent Packs"
  - ScrollContainer with VBoxContainer for pack history (click to add)
- Remove/hide the PackSelectorContainer overlay entirely

**1.4 Create Tab 3 - Mode:**
- Add VBoxContainer as child of TabContainer, name it "Mode"
- Move SessionTypeSwitcher here
- Move session panels here
- Add HBoxContainer at bottom for buttons:
  - Button: "💾 Save Session"
  - Button: "Let's draw!"

**1.5 Add Navigation:**
- Add HBoxContainer below TabContainer for navigation buttons:
  - Button: "← Previous" (hidden on first tab)
  - Button: "Next →" (hidden on last tab, replaced by done button)

### Phase 2: Script Modularization

**2.1 Create tab_session.gd** (Done)
- Manages session history and loading
- Signals: `session_selected(path)`, `new_session_requested`
- Method: `is_valid()` - always returns true

**2.2 Create tab_packs.gd** (Done)
- Manages pack selection and display
- Signals: `packs_changed`
- Method: `is_valid()` - returns true if at least one pack with images exists
- Method: `set_context(context)`
- Integrates folder dialog, images dialog, pack history directly

**2.3 Create tab_mode.gd** (Done)
- Manages session type and configuration
- Signals: `mode_changed`
- Method: `is_valid()` - delegates to current session panel
- Method: `set_context(context)`
- Method: `get_context()` - returns SessionResource with latest state

**2.4 Simplify menu.gd** (Done - see menu_new.gd)
- Main controller that coordinates tabs
- Handles tab validation and navigation
- Prevents proceeding to next tab if current tab invalid
- Manages session save/load via tabs

### Phase 3: Validation System

**3.1 Tab Validation:**
```gdscript
func _update_navigation_buttons() -> void:
    var current_tab := tab_container.current_tab
    
    match current_tab:
        0:  # Session tab
            next_button.disabled = not tab_session.is_valid()
        1:  # Packs tab
            next_button.disabled = not tab_packs.is_valid()
        2:  # Mode tab
            done_button.disabled = not tab_mode.is_valid()
```

**3.2 Navigation Prevention:**
```gdscript
func _on_next_pressed() -> void:
    if not _current_tab_is_valid():
        return  # Don't proceed
    tab_container.current_tab += 1
```

### Phase 4: Theme Improvements

**4.1 TabContainer Styling:**
- In default_theme.tres, add TabContainer styles:
  - Larger tab buttons
  - Better contrast for active tab
  - Full-width tabs with centered text

**4.2 Button Styling:**
- Primary button style (Let's draw, Next)
- Secondary button style (Previous, Save Session)
- Icon buttons for pack actions

**4.3 Spacing:**
- Consistent margins and padding
- Proper separation between sections
- Better visual hierarchy

### Phase 5: Integration Steps

1. Open project in Godot Editor
2. Open scenes/menu/menu.tscn
3. Follow Phase 1 steps to restructure the scene
4. Attach tab_session.gd to Session tab VBoxContainer
5. Attach tab_packs.gd to Packs tab VBoxContainer
6. Attach tab_mode.gd to Mode tab VBoxContainer
7. Replace menu.gd with menu_new.gd
8. Connect signals in editor
9. Test and adjust

## Files Created

- `scenes/menu/tab_session.gd` - Session tab controller
- `scenes/menu/tab_packs.gd` - Packs tab controller
- `scenes/menu/tab_mode.gd` - Mode tab controller
- `scenes/menu/menu_new.gd` - New simplified main menu controller

## Migration Notes

### Required Node Names (unique names with %)
In menu.tscn after refactor:
- %TabContainer
- %TabSession
- %TabPacks
- %TabMode
- %NextButton
- %PrevButton
- %DoneButton
- %SaveSessionButton

In tab_session scene/node:
- %NewSessionButton
- %ImportSessionButton
- %SessionHistoryContainer

In tab_packs scene/node:
- %PackContainer
- %PackHistoryContainer
- %FolderButton
- %ImagesButton
- %PinterestButton
- %InfoLabel
- %FolderDialog
- %ImagesDialog

In tab_mode scene/node:
- %SessionTypeSwitcher
- %SessionPanelContainer

## Testing Checklist

- [ ] Session tab loads and displays history
- [ ] Import session works and loads context
- [ ] New session clears data and proceeds to packs tab
- [ ] Can't proceed from session tab without selecting/starting session (currently always valid)
- [ ] Pack tab displays selected packs correctly
- [ ] Pack history items can be added to selection
- [ ] Can't proceed from packs tab without selecting at least one pack
- [ ] Mode tab shows correct session type
- [ ] Mode configuration saves to context
- [ ] Save session button creates .gsession file
- [ ] Let's draw button starts session with correct context
- [ ] Navigation buttons show/hide correctly per tab
- [ ] Tabs take full horizontal space
- [ ] Theme looks polished

## Notes

This refactor converts from a runtime-generated tab system to a scene-based design, which is more maintainable and allows for better visual design in the Godot editor. The validation system ensures users complete each step before proceeding.
