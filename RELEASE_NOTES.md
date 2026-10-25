# v1.7.1 - Code block rendering fix and OpenCode Go session header

Two fixes: replies with code blocks render the text after them correctly again, and OpenCode Go accepts requests now that its gateway demands a session header.

## Fixed

- **Code fences no longer restyle everything below them.** The code block renderer in `ui.html` emitted a second opening `<code>` where the closing tag belonged:

  ```js
  `<pre><code>${text}<code></pre>`   // before
  `<pre><code>${text}</code></pre>`  // after
  ```

  `<code>` is a formatting element in the HTML parser. `</pre>` closed the fence but left `code` on the active formatting elements list, so every start tag after the fence rebuilt it. Prose after a code block switched to Consolas, stopped wrapping and was clipped at the right edge, and the Copy and Collapse buttons were pulled out of their wrapper. With the tag closed, later paragraphs, headings, rules and lists render in the body font and wrap at the WebView width. Collapse still clamps the fence to one line.
- **OpenCode Go rejects requests without a stable session header** (`{"type":"error","error":{"type":"MissingSessionID",...}}`). The provider entry now sends `x-opencode-session` and a `llmclip` user agent, as that gateway asks for both.
- **The OpenCode Go model list matches what the endpoint still serves.** Only `deepseek-v4.1-flash` remains. `deepseek-v4-flash`, `deepseek-v4-pro` and `qwen3.6-plus` are gone from `providers.json`.

## New

- `{SESSION_ID}` curl placeholder, which resolves to a stable per-conversation ID (`llmclip-<session index>`). Any provider template can use it, not just OpenCode Go, for gateways that route or cache by session.

## Docs

- Tool auto-approval examples now key their patterns by `tool_id` (`execute_powershell`, `file_system`, `web_search`, `web_fetch`, `read_url_markdown`) instead of class name, which is what `ExecuteToolCallsCommand` matches on. A pattern written the old way never fired.
- Dropped `roles.json` and `TOOL_AUTO_APPROVAL.md` from the layout and plugin docs. Neither file exists anymore.

## Upgrading

Replace `ui.html` and `providers/providers.json` in an existing install. A local `providers.json` without the `x-opencode-session` header keeps failing on OpenCode Go no matter what the app binary is.

## Specs

All 21 specs pass `openspec validate --all --strict`.
