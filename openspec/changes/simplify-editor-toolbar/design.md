## Context

The OverType editor is instantiated in `ui.html` when a user double-clicks a message in the history list. It renders a Markdown editor with a toolbar. The toolbar is configured via the `toolbarButtons` array.

## Goals / Non-Goals

**Goals:**
- Remove all formatting buttons (bold, italic, code, link, headings, bullet list, quote) and their separators from the toolbar
- Keep only cancel (✕) and save (💾) buttons

**Non-Goals:**
- Changing anything about the editing functionality itself
- Modifying the WebViewManager, controllers, or any AHK code

## Decisions

### Single file change

**Chosen**: Edit only `ui.html`, lines 328-358 — trim the `toolbarButtons` array to two entries (cancel, save).

**Rationale**: The toolbar is a pure frontend concern. No backend code references toolbar buttons. No architectural layers are touched.

## Risks / Trade-offs

- **Loss of formatting**: Users can no longer apply bold, italic, etc. while editing. They can still type Markdown directly. Mitigation: the use case is correcting LLM responses, not authoring rich documents — plain text edits are sufficient.
