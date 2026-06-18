## Why

When images are attached as context in a conversation, they do not get a separate clickable row in the history view like text context does. Instead, image info is flattened into the user message row as bare `[Image]` text, and clicking the row does not display the actual image. This breaks review workflows — users must re-attach images to see them again. Text context already works correctly: a separate 📎 row appears, and clicking it renders the context content in the WebView. Images should behave the same way.

## What Changes

- Image-only context messages get a separate 📎 row in the history view (same as text context), with a label indicating the number of attached images
- Clicking the image context row renders the actual image(s) in the WebView using the existing markdown image pattern (`![Image](data:image/...;base64,...)`)
- Mixed messages (text context + images) show both in the context row: text rendered as markdown, images rendered as inline `<img>` tags
- The user message row (👤) correctly excludes images from its preview, showing only the typed prompt text

## Capabilities

### New Capabilities

- `image-context-history`: Images attached as context appear as a separate, clickable row in the chat history view. Clicking the row shows the image in the WebView. Mixed text+image context in a single message is supported.

### Modified Capabilities

<!-- None — this is net-new behavior, not a change to existing spec-level requirements -->

## Impact

- **Commands**: `SendToLLMCommand.ahk` — one additional condition to set `hasContext = true` when images are present
- **Utils**: `MessagePresentationService.ahk` — three methods updated (`GetContextListViewItem`, `GetContextPresentationText`, `GetPresentationText`) to handle `ImageContent` parts
- **No new files**, no new classes, no breaking changes to existing behavior
- WebView (`ui.html`) requires no changes — already supports `![Image](data:...)` markdown with `sanitize: false`
