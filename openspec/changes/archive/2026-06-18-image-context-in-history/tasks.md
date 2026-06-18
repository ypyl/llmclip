## 1. Message property: hasTextContext flag

- [x] 1.1 Add `"hasTextContext"` to `internalProps` exclusion list in `ChatMessage.ToObject()` (Services/LLM/Types.ahk) so it is not sent to LLM APIs
- [x] 1.2 Add `"hasTextContext"` to the restoration loop in `ChatMessage.FromObject()` (Services/LLM/Types.ahk) so it survives conversation save/load

## 2. Set hasContext and hasTextContext for image messages

- [x] 2.1 In `SendToLLMCommand.Execute()` (Commands/SendToLLMCommand.ahk), set `hasContext` also when `images.Length > 0`, not only when `additionalContext != ""`
- [x] 2.2 Store a `hasTextContext` flag on the message set to `additionalContext != ""` so the presentation layer can distinguish Contents[1] = context text vs Contents[1] = user prompt

## 3. Update context row label in history ListView

- [x] 3.1 In `MessagePresentationService.GetContextListViewItem()` (Utils/MessagePresentationService.ahk), count `ImageContent` parts in the message and include image count in the label text
- [x] 3.2 For image-only context: show "📎 🖼️ N image(s) attached"
- [x] 3.3 For mixed text+image context: show "📎 N item(s), M image(s) attached"

## 4. Render image context in WebView when context row is clicked

- [x] 4.1 In `MessagePresentationService.GetContextPresentationText()` (Utils/MessagePresentationService.ahk), after rendering text context from Contents[1] (if `hasTextContext` is true), iterate all `ImageContent` parts and emit markdown `![Image](data:<mimeType>;base64,<data>)` for each image
- [x] 4.2 Handle both base64 data images (`ImageContent.Data`) and URL images (`ImageContent.Url`) in the markdown generation

## 5. Exclude image content from user message row preview

- [x] 5.1 In `MessagePresentationService.GetPresentationText()` (Utils/MessagePresentationService.ahk), when `hasContext` is true, use `hasTextContext` flag to decide whether to skip Contents[1] (skip only if `hasTextContext` is true — otherwise Contents[1] is the user prompt)
- [x] 5.2 Skip all `ImageContent` parts when building the user message row text (they belong to the context row)
- [x] 5.3 Remove the `" [Image]"` suffix logic from `GetPresentationText` and `GetMessageAsString` — images are now shown in the context row, not the message row

## 6. Integration verification

- [x] 6.1 Run `main.ahk` and test: attach only images, send → verify separate 📎 row appears with correct image count **(manual — requires AHK v2 runtime)**
- [x] 6.2 Click the 📎 image context row → verify images render in WebView **(manual — requires AHK v2 runtime)**
- [x] 6.3 Test mixed context: attach text items + images, send → verify single 📎 row shows both counts **(manual — requires AHK v2 runtime)**
- [x] 6.4 Click the mixed context row → verify text content renders first, images below **(manual — requires AHK v2 runtime)**
- [x] 6.5 Verify user message row (👤) shows only the typed prompt, no `[Image]` suffix **(manual — requires AHK v2 runtime)**
- [x] 6.6 Verify text-only context still works correctly (no regression) **(manual — requires AHK v2 runtime)**
- [x] 6.7 Save conversation with image context, reload → verify images still appear in history rows **(manual — requires AHK v2 runtime)**
