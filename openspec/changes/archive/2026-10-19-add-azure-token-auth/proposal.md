## Why

Every provider in `providers/providers.json` authenticates with a static secret read from `keys.ini`. For the company Azure OpenAI deployment this is the wrong model: the API key is a long-lived shared secret that cannot be tied to a person, rotated per user, or governed by Conditional Access. The tenant already issues short-lived Entra ID access tokens to the Azure CLI, and the user is signed in and holds the `Cognitive Services OpenAI User` role on the resource.

The request path already treats the credential as an opaque string substituted into a curl template. Supporting SSO therefore does not require new HTTP plumbing. It requires a way to obtain and cache that string at call time instead of reading it from a file.

## What Changes

- Providers may declare an optional `auth` object in provider JSON with `type: "command"` and a `command` that prints an access token on stdout.
- New `TokenService` (Service layer) executes the auth command, caches the token per command string with a TTL and skew, and invalidates on request.
- `LLMClient.Call()` substitutes a new `{AUTH_TOKEN}` placeholder from `TokenService`. The existing `{API_KEY}` path is unchanged.
- `LLMClient.Call()` invalidates the cached token when a response indicates `401`, so a revoked or expired token self-heals on the next send.
- A new optional `{HEADERS_FILE}` placeholder lets a provider read its `Authorization` header from a temp file via `curl -H @file`, keeping the token out of the process command line.
- `Providers.ahk` stops skipping `providers.json` when a second provider file exists, so company-specific providers can live in a gitignored file instead of the public default.
- No UI change. `az login` happens outside the app.

## Capabilities

### New Capabilities
- `provider-auth`: Providers can declare a command-based credential source. Tokens are obtained, cached, refreshed, invalidated, and never exposed on the command line or in trace logs.

### Modified Capabilities
<!-- None. The `{API_KEY}` path and `provider_type` routing are untouched. -->

## Layer Impact

- **Service (new)**: `Services\Auth\TokenService.ahk`
- **Service (modified)**: `Services\LLM\LLMClient.ahk`, `Services\Configuration\Providers.ahk`
- **Composition root**: `App.ahk` (one `#Include`, one instantiation, one constructor argument)
- **Config (not code)**: `providers\azure.json` (gitignored), `providers\azure.example.json` (tracked)
- **Untouched**: Views, Controllers, Commands, `keys.ini`, `ConfigurationService`

No layer boundary violations: `TokenService` is a Service that owns OS/process state and holds no UI, controller, or command references. `LLMClient` is a Service and already depends on other services (`TraceabilityService`).

## Verification

- Headless AHK script includes `TokenService.ahk` with a stub command (`cmd /c echo eyJfake`), asserts cache hit, cache miss after `Invalidate()`, and error on non-token output.
- Headless script calls `LLMClient.Call()` with a stub provider and a template containing `{AUTH_TOKEN}`, asserting the token reached the request body.
- Manual: run `main.ahk`, send a message to the Azure model, confirm HTTP 200, confirm `wmic process where "name='curl.exe'" get commandline` shows no token, confirm the response renders.
- Manual: send a message to a `keys.ini` provider (Groq) and confirm it still works.

## Rollback

Remove the Azure provider entry from `providers\azure.json` and delete the file. Every other provider uses the untouched `{API_KEY}` path. `TokenService` becomes dead code and can be removed with the `#Include` line. No persisted state changes, so nothing to migrate.

## Impact

- Existing `keys.ini` providers: no behaviour change.
- Token acquisition adds roughly 800 ms on a cold call (measured `az account get-access-token` on this machine) and nothing on a cache hit.
- `providers.json` merge behaviour changes: a second provider JSON file now adds to the defaults instead of replacing them. Nothing in the repo relies on the old behaviour.
