## Why

The OverType editor toolbar in the message edit view has 12 formatting buttons (bold, italic, code, link, headings, bullet list, quote) that are rarely used for editing LLM responses. They clutter the toolbar and distract from the two actions that matter: save and cancel. Stripping the toolbar to just those two buttons makes the edit experience cleaner and faster.

## What Changes

- Remove all formatting buttons and separators from the OverType toolbar configuration in `ui.html`
- Keep only the cancel and save action buttons

## Capabilities

### New Capabilities
<!-- None — purely a UI simplification, no new capabilities -->

### Modified Capabilities
<!-- None — no existing spec covers the editor toolbar -->

## Impact

- **Modified**: `ui.html` — trim the `toolbarButtons` array to only the cancel and save objects
