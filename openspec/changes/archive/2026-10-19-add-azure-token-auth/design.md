## Context

`LLMClient.Call()` builds a shell command from a curl template stored in provider JSON:

```
curl -s -S -X POST "https://api.groq.com/openai/v1/chat/completions" \
  -H "Authorization: Bearer {API_KEY}" -d "@{1}" -o "{2}"
```

Two placeholders are substituted before `Run()`: `{API_KEY}` from `settings["api_key"]` (populated by `ConfigurationService.GetSelectedSettings` from `keys.ini`) and `{MODEL}` from `settings["model"]`. `Format(curl, inputFile, outputFile)` fills `{1}` and `{2}`. If `{API_KEY}` survives substitution, the call throws.

So the credential is already an opaque string at a single substitution point. The change is where that string comes from.

Verified on the target machine before writing this design:

| Check | Result |
|---|---|
| `az version` | 2.91.0, installed at `C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az` |
| `az account show` | signed in, tenant `93faadee-...`, subscription `CTO Office D` |
| `az account get-access-token --resource https://cognitiveservices.azure.com` | returns a 3888 character JWT |
| latency | about 800 ms, and the CLI returns an identical cached token on repeat calls |
| `curl --version` | 8.21.0, supports `-H @file` (verified with a live request) |
| role | `Cognitive Services OpenAI User` on the resource |

Endpoint shape is the legacy Azure OpenAI surface: `https://<resource>.openai.azure.com/openai/deployments/{MODEL}/chat/completions?api-version=<version>`, deployment name in the path, `api-version` required, token audience `https://cognitiveservices.azure.com`.

## Goals / Non-Goals

**Goals**

- Company Azure OpenAI provider authenticates with an Entra ID token obtained from the already-signed-in Azure CLI.
- Zero change to the existing `{API_KEY}` providers.
- Token captured once per TTL, not once per message.
- Token does not appear in a process command line or in `sessions/*.jsonl`.
- Auth failure produces a message that says what to do.
- Company endpoint configuration stays out of the public repository.

**Non-Goals**

- In-app sign-in, device code flow, or any browser interaction. `az login` is a prerequisite, run outside the app.
- Refresh tokens or a credential cache. The CLI owns those.
- Background token refresh. Fetching on demand, once per TTL, is enough.
- Supporting `gh auth token`, `gcloud`, or any other CLI as part of this change. The mechanism generalises; the configuration does not ship.
- Concurrent or streaming requests.
- Reworking `ConfigurationService` or the `keys.ini` model for non-auth providers.

## Decisions

### Decision 1: `auth` object in provider JSON, `{AUTH_TOKEN}` placeholder

```jsonc
"AzureOpenAI": {
  "provider_type": "openai",
  "auth": {
    "type": "command",
    "command": "az account get-access-token --resource https://cognitiveservices.azure.com --query accessToken -o tsv",
    "ttl_seconds": 900,
    "skew_seconds": 60,
    "login_hint": "az login"
  },
  "curl": "curl -s -S -X POST \"https://co.openai.azure.com/openai/deployments/{MODEL}/chat/completions?api-version=2024-10-21\" -H @\"{HEADERS_FILE}\" -H \"Content-Type: application/json\" -d \"@{1}\" -o \"{2}\"",
  "models": [ { "model": "gpt-4o", "tools": [ "file_system" ] } ]
}
```

`Providers.Reload()` copies every provider key except `models` into each model's merged settings, so `auth` arrives in `settings` with no change to that file.

Rationale for a separate placeholder rather than overloading `{API_KEY}`:

1. The error paths stay distinguishable (`Missing API_KEY` vs `Missing AUTH_TOKEN` name different fixes).
2. `GetApiKey()` correctly returns `""` for this provider, and no code has to reason about "an API key that is not an API key".
3. Existing provider templates need no edit.

### Decision 2: `TokenService` owns process execution and cache

`Services\Auth\TokenService.ahk`, one class, no strategy hierarchy.

```ahk
class TokenService {
    cache := Map()          ; command string -> {token, expiresAt}
    isCancelled := false
    pid := 0

    GetToken(authConfig)    ; -> token string, throws on failure
    Invalidate(authConfig)  ; drop one cache entry
    Cancel()
}
```

Keyed by the command string, not by provider name, so two providers that share a resource share a token.

Not injected into `ConfigurationService`. `ConfigurationService.GetSelectedSettings` is called from many places and is a pure config read; running a subprocess there would make config reads slow and side-effecting. Injection into `LLMClient` keeps the cost on the request path only.

### Decision 3: Non-blocking execution, mirroring `PowerShellTool`

`RunWait` blocks the AHK message loop, so the window freezes and `Cancel()` cannot fire. `PowerShellTool.ExecuteScript()` already solves this with `Run(..., "Hide", &pid)` plus a `ProcessExist` poll loop. Copy that pattern.

Execution detail: `az` is a `.cmd` shim, and AHK `Run` cannot capture stdout. Wrap in `cmd.exe /c` with redirects, writing stdout and stderr to separate files:

```
cmd.exe /c ""C:\...\az.cmd" account get-access-token ... > "temp\_token_out.txt" 2> "temp\_token_err.txt""
```

Separate files matter: the CLI writes warnings to stderr, and merging them would corrupt the token.

### Decision 4: Fixed TTL with skew, plus 401 invalidation. Do not parse the CLI's expiry output.

`az ... --query expiresOn -o tsv` returns `2026-10-19 11:43:52.000000`. Parsing that requires either a second subprocess call or a fragile format match, and the format is not a contract.

More important: token lifetime is set by tenant policy, and Conditional Access can shorten it well below the 60 to 75 minute default. A TTL read from one token does not predict the next.

So: `ttl_seconds` (default 900) and `skew_seconds` (default 60) from config, plus `Invalidate()` on any `401`. A wrong TTL costs one failed request and self-heals on the next send. This is simpler and more robust than expiry introspection.

Rejected alternative: run the command on every call. Correct, but pays 800 ms per message and every tool round trip for a credential that changes hourly.

### Decision 5: Token stays off the command line via `{HEADERS_FILE}`

`Run(curlCmd)` puts the whole command line into `Win32_Process.CommandLine`, readable by any process. The Entra token is 3888 characters, so this is both a leak and a long command line.

When a template contains `{HEADERS_FILE}`, `LLMClient` writes `temp\auth_headers.txt` containing `Authorization: Bearer <token>` and substitutes the path. curl 8.21 reads it with `-H @file`. The file is deleted in the existing `finally` block.

`{HEADERS_FILE}` is opt-in per provider. Existing templates are untouched, so this is a zero-risk addition that also gives a path to fix `{API_KEY}` leaks later.

### Decision 6: Company provider lives in a gitignored file, so `skipDefault` goes

`Providers.Reload()` currently contains:

```ahk
skipDefault := fileCount > 1
```

Adding `providers/azure.json` therefore disables `providers.json` and drops all nine built-in providers. That is a trap regardless of this change.

Remove the `skipDefault` branch so all provider JSON files merge additively. Files are read in glob order, provider-level keys are set on first sight, models merge by name. Nothing in the repo relies on replacement behaviour.

Then:

- `providers/azure.example.json` is tracked and contains placeholders (`https://YOUR-RESOURCE.openai.azure.com`).
- `providers/azure.json` is gitignored and holds the real endpoint.
- Release zip continues to ship only `providers/providers.json`, so the company endpoint never enters a public release artifact.

Rejected alternative: put the real hostname in `providers/providers.json`. The repository is public.

### Decision 7: Failure messages carry the hint from config

If the command output does not look like a token (does not start with `eyJ`), `TokenService` throws with the captured stderr and the optional `login_hint`:

> Token acquisition failed for AzureOpenAI. Run `az login` and retry. Details: <stderr>

`LLMClient.Call()` already wraps everything in `try/catch` that converts a thrown error into an assistant message, so a failed token fetch renders in the chat instead of crashing. No controller or view change is needed.

### Decision 8: Traceability stays body-only

`TraceabilityService.LogInteraction` records the request body, raw response, and timings. Headers are not recorded and the token is never in the body. This invariant must be preserved: do not move the auth header into the JSON body (for example an `api-key` field), and do not add header logging.

### `#Include` additions in `App.ahk`

Exactly one, placed next to the other LLM service includes:

```ahk
#Include Services\Auth\TokenService.ahk
```

`TokenService.ahk` itself includes:

```ahk
#Include ..\..\Lib\Json.ahk
```

No other new include is required. `Providers.ahk` and `LLMClient.ahk` already resolve.

### Dependency graph

```
App.ahk (composition root)
  ├── TokenService          (new, no outgoing service deps beyond Lib\Json)
  ├── ConfigurationService  (singleton, unchanged)
  │     └── Providers       (modified: merge all provider JSON files)
  └── LLMService
        └── LLMClient       (modified: {AUTH_TOKEN}, {HEADERS_FILE}, 401 invalidation)
              ├── TokenService   (constructor injection, new)
              └── TraceabilityService (unchanged)
```

No cycles. `TokenService` depends on nothing in the app. `LLMClient` gains one constructor parameter.

### Wiring in `App.ahk`

```ahk
tokenService := TokenService()
clientInstance := LLMClient(trc, llmProviders, tokenService)
```

Constructor order keeps optional-last so the change is one line at the call site.

## Risks

| Risk | Mitigation |
|---|---|
| Wrong token audience returns `401 Invalid audience` and reads like an SSO failure | Resource is `https://cognitiveservices.azure.com` for `*.openai.azure.com`, encoded in the provider config, not in code |
| Token leaks through the command line | `{HEADERS_FILE}` on the Azure provider from the start |
| `RunWait` freezes the UI | `Run` + `ProcessExist` poll, same as `PowerShellTool` |
| Tenant shortens token lifetime below the TTL | 401 invalidation on the next send; `ttl_seconds` is config, not code |
| `az` not installed on a colleague's machine | Error names the command and the `login_hint`; no silent failure |
| Company hostname published | `providers/azure.json` gitignored, example file tracked, release zip unchanged |
| Two concurrent requests share `temp\request.json` | Pre-existing limitation, unchanged by this work, out of scope |
