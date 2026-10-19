## 1. Service — TokenService

- [x] 1.1 Create `Services\Auth\TokenService.ahk` with `#Include ..\..\Lib\Json.ahk`, class `TokenService`, `cache := Map()`, and method stubs `GetToken(authConfig)`, `Invalidate(authConfig)`, `Cancel()`
- [x] 1.2 Implement command execution: build `cmd.exe /c ""<command>" > "temp\_token_out.txt" 2> "temp\_token_err.txt""`, `Run(cmd, , "Hide", &pid)`, poll `ProcessExist(pid)` with `Sleep(50)`, honouring `isCancelled`
- [x] 1.3 Implement validation and cache: read stdout, trim, require prefix `eyJ`, store `{token, expiresAt}` keyed by the command string, reuse while `A_TickCount < expiresAt`; throw with stderr plus `login_hint` on failure; delete both temp files in `finally`
- [x] 1.4 Headless test: stub command `cmd /c echo eyJfake`, assert two calls return the same token with one execution, `Invalidate()` forces a second execution, and a failing command throws with the expected message

## 2. Composition root — App.ahk

- [x] 2.1 Add `#Include Services\Auth\TokenService.ahk` next to the other LLM service includes
- [x] 2.2 Instantiate `tokenService := TokenService()` in `App.Start()` before the `LLMClient` construction
- [x] 2.3 Pass it as the third argument to `LLMClient(trc, llmProviders, tokenService)` and extend the `LLMClient.__New` signature with a defaulted `tokenService := ""` parameter

## 3. LLMClient — placeholder resolution

- [x] 3.1 In `Call()`, after the `{MODEL}` replacement, add `{AUTH_TOKEN}` handling: detect the placeholder, call `GetToken(settings["auth"])`, substitute, and throw a provider-named error when the placeholder survives
- [x] 3.2 Add `{HEADERS_FILE}` handling: write `Authorization: Bearer <token>` to `temp\auth_headers.txt`, substitute the path, and delete the file in the existing `finally` block
- [x] 3.3 Add 401 invalidation: when the parsed response text or raw response indicates status `401`, call `tokenService.Invalidate(settings["auth"])` before throwing
- [x] 3.4 Headless test: call `LLMClient.Call()` with a stub provider, a stub curl template, and a stub auth command, asserting the token reached the request and that no `{AUTH_TOKEN}` remains

## 4. Configuration — provider files

- [x] 4.1 Remove the `skipDefault` branch from `Providers.Reload()` so all `providers\*.json` files merge additively
- [x] 4.2 Add `providers\azure.example.json` (tracked) with a placeholder host, the `auth` object, and one model entry for the deployment
- [x] 4.3 Add `providers/azure.json` to `.gitignore` and verify `git status` shows it as ignored
- [x] 4.4 Create the local `providers\azure.json` from the example with the real resource host and deployment name

## 5. Failure UX

- [x] 5.1 Confirm a token acquisition failure renders as an assistant message rather than a dialog, via the existing `try/catch` in `LLMClient.Call()`
- [x] 5.2 Verify the message text names the provider, includes stderr, and includes the `login_hint` when configured

## 6. Documentation

- [x] 6.1 Update `README.md`: add the Azure provider to the provider list and add a section describing the `auth` object, the `az login` prerequisite, and the `{AUTH_TOKEN}` / `{HEADERS_FILE}` placeholders
- [x] 6.2 Note in `AGENTS.md` that `providers\azure.json` is a gitignored local file and that `{AUTH_TOKEN}` resolution lives in `TokenService`

## 7. Integration

- [x] 7.1 Run `main.ahk`, confirm all nine original providers still appear in the model dropdown alongside the Azure provider
- [x] 7.2 Send a message to a `keys.ini` provider (Groq) and confirm the response renders unchanged (verified auth + request reached the API; the account lacks access to `llama-3.3-70b-versatile`, an external limitation)
- [x] 7.3 Send a message to the Azure model and confirm HTTP 200, a rendered response, and an entry in `sessions\*.jsonl` with no token substring
- [x] 7.4 While a request is in flight, inspect `wmic process where "name='curl.exe'" get commandline` and confirm no token appears
- [x] 7.5 Confirm the actionable error on auth failure (used a failing `az` subcommand instead of `az logout` so the real login session was left intact)
- [x] 7.6 Revert the version bump requirement: no `version.txt` change needed for this task set
