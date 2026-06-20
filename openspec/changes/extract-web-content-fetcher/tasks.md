## 1. New utility

- [ ] 1.1 Create `Utils/WebContentFetcher.ahk` with static `FetchMarkdown(url)` method — extract the curl, temp file, and response reading logic from `MarkdownNewTool.Execute()`, without the cancellation loop
- [ ] 1.2 Add `#Include Utils\WebContentFetcher.ahk` to `App.ahk`

## 2. Refactor MarkdownNewTool

- [ ] 2.1 Replace the HTTP logic in `MarkdownNewTool.Execute()` with a call to `WebContentFetcher.FetchMarkdown(url)`, keeping only the upfront `isCancelled` check

## 3. Refactor ReplaceLinkWithContentCommand

- [ ] 3.1 Replace `this.markdownNewTool` dependency with a direct call to `WebContentFetcher.FetchMarkdown(contextItem)` — the JSON parsing and context formatting in the command remain unchanged
- [ ] 3.2 Remove the `markdownNewTool` constructor parameter and property

## 4. Update App.ahk wiring

- [ ] 4.1 Remove the `mdn := mnt` alias
- [ ] 4.2 Update `ReplaceLinkWithContentCommand` constructor call to remove the `mdn` parameter

## 5. Verification

- [ ] 5.1 Run `main.ahk` and smoke-test: add a URL to context, click "Replace Link with Content", verify content is fetched and displayed
- [ ] 5.2 Smoke-test the LLM tool path: ask the LLM to fetch a URL via markdown.new tool, verify it works
