## Context

When a user sends a message through LLMClip, attached context (clipboard text, files, images, URLs) is bundled into the `ChatMessage.Contents` array. The message is marked with `hasContext` in `AdditionalProperties` if text-based context was included. In the history view (a Win32 ListView), the `GetHistoryListItemsCommand` reads this flag and inserts a synthetic "📎" row before the user message — clicking that row renders the context content in the WebView via `MessagePresentationService.GetContextPresentationText`.

The problem: `hasContext` is only set when `additionalContext != ""` (a text string built by `ContextManager.BuildPromptContext`). Images bypass this path entirely — they're passed separately via `MainController.AskToLLM` → `SendToLLMCommand` → `SessionManager.BuildUserMessage`, which creates `ImageContent` objects in the Contents array but sets no `hasContext` flag. As a result, image-only messages get no 📎 row, and the image presence is reduced to a bare `[Image]` suffix on the user message row text.

The WebView (`ui.html`) already supports rendering images via markdown `![Image](data:image/...;base64,...)` tags (proven by the context list click behavior in `ContextManager.GetTextFromContextItem`). No HTML/JS changes are needed.

## Goals / Non-Goals

**Goals:**
- Images attached as context produce a separate 📎 clickable row in the history ListView
- Clicking the image context row renders the actual image(s) in the WebView
- Mixed messages (text context + images) show both in the context row
- The user message row excludes context-only content (images and context text) from its preview

**Non-Goals:**
- PDF context in history (out of scope, ignored)
- Drag-and-drop or inline image editing in the WebView
- Persisting image data differently (existing serialization is unchanged)
- Changing the context ListView behavior (already works correctly)

## Decisions

### Decision 1: Track text vs image context separately

**Chosen**: Store a `hasTextContext` flag on the message's `AdditionalProperties` in addition to the existing `hasContext` flag.

**Rationale**: The Contents array mixes text and image parts without a reliable positional marker. When only images are present (no `additionalContext` text), `Contents[1]` could be either the user prompt text or empty — we can't distinguish "this is context" from "this is user text" by position alone. The `hasTextContext` flag (set to `additionalContext != ""`) tells the presentation layer whether `Contents[1]` is context text or user prompt text.

**Alternative considered**: Count and skip `ImageContent` parts while assuming all `TextContent` parts after Contents[1] are user text. Rejected because it's fragile — a future change adding text context at multiple positions would break the assumption silently.

### Decision 2: Reuse markdown image pattern for WebView rendering

**Chosen**: Generate `![Image](data:<mimeType>;base64,<data>)` markdown from `ImageContent` objects in `GetContextPresentationText`.

**Rationale**: This is the exact pattern already used by `ContextManager.GetTextFromContextItem` when rendering images from the context list. The WebView's `marked.parse()` with `sanitize: false` converts this to a native `<img>` tag. Zero WebView changes required.

**Alternative considered**: Emit raw HTML `<img>` tags. Rejected because it breaks consistency — the rest of the system uses markdown for content rendering.

### Decision 3: No new files or classes

**Chosen**: All changes are localized to existing static methods in `MessagePresentationService` (Utils layer) and one condition in `SendToLLMCommand` (Commands layer).

**Rationale**: The change is a behavioral fix within the existing presentation logic, not a new feature or capability. Adding new classes would violate the architecture's simplicity principle and require new `#Include` entries in `App.ahk`.

### Decision 4: Image count in context row label

**Chosen**: The 📎 row label counts `ImageContent` parts separately from text items. Format: `"📎 N item(s), M image(s) attached"` when both are present; `"📎 🖼️ N image(s) attached"` for images only.

**Rationale**: Users need to know at a glance what's in a context row. The text-only label (`"N context item(s) attached"`) is ambiguous when images are mixed in.

## Risks / Trade-offs

- **[Risk] Base64 images can be large**: A message with multiple high-res images will produce a large Markdown string for WebView rendering. → **Mitigation**: The context ListView already handles this without issues. Base64 rendering is browser-native (no JS processing overhead). No evidence of slowness in the existing context-list image flow.

- **[Risk] `hasTextContext` is a new message property**: It must survive serialization/deserialization for conversation save/load. → **Mitigation**: `AdditionalProperties` in `ChatMessage.ToObject` and `ChatMessage.FromObject` already serialize all properties that aren't in the `internalProps` exclusion list. We add `"hasTextContext"` and `"imageCount"` to the exclusion list (they're display-only metadata, rebuilt from Contents on load).

- **[Trade-off] `imageCount` recalculated on every list refresh**: Rather than persisting `imageCount`, it's computed by counting `ImageContent` parts when building list items. → This is cheap (< 10 parts per message) and avoids serialization complexity.
