## ADDED Requirements

### Requirement: Provider auth is declared in provider JSON
A provider entry in any `providers\*.json` file SHALL be able to declare an optional `auth` object. When present, the object SHALL contain `type` with the value `"command"`, a `command` string that prints an access token to stdout, and MAY contain `ttl_seconds` (default `900`), `skew_seconds` (default `60`), and `login_hint`. The merged model settings produced by `Providers.Get()` SHALL include the `auth` object unchanged.

#### Scenario: Auth object reaches model settings
- **WHEN** a provider entry declares `"auth": { "type": "command", "command": "az account get-access-token ..." }`
- **AND** a model from that provider is selected through `ConfigurationService.GetSelectedSettings()`
- **THEN** the settings Map contains an `auth` key whose value is a Map with `type` = `"command"` and the configured `command`

#### Scenario: Provider without auth is unaffected
- **WHEN** a provider entry declares no `auth` object
- **THEN** the merged settings contain no `auth` key
- **AND** `GetApiKey()` and the `{API_KEY}` substitution behave exactly as before

### Requirement: AUTH_TOKEN placeholder is resolved at call time
`LLMClient.Call()` SHALL replace `{AUTH_TOKEN}` in the curl template with the token returned by `TokenService.GetToken(settings["auth"])` when settings contain an `auth` key. The service SHALL be consulted only when the template contains `{AUTH_TOKEN}`.

#### Scenario: Token substituted into the command
- **WHEN** the settings contain an `auth` object and the curl template contains `{AUTH_TOKEN}`
- **THEN** `TokenService.GetToken()` is called once and its return value replaces `{AUTH_TOKEN}` before `Run()` executes

#### Scenario: Token fetched but unused
- **WHEN** the settings contain an `auth` object and the curl template contains no `{AUTH_TOKEN}`
- **THEN** `TokenService.GetToken()` is not called and no subprocess is spawned

#### Scenario: Placeholder present without auth config
- **WHEN** the curl template contains `{AUTH_TOKEN}` but the settings contain no `auth` key
- **THEN** `LLMClient.Call()` throws an error naming the provider and stating that auth is not configured for it

### Requirement: Tokens are cached with a TTL and skew
`TokenService` SHALL cache each token against its auth command string. A cached token SHALL be reused while the current time is earlier than `acquiredAt + (ttl_seconds - skew_seconds)`. On a miss or an expired entry the command SHALL be executed and the result cached.

#### Scenario: Cache hit
- **WHEN** `GetToken()` is called twice within the TTL window with the same `auth` config
- **THEN** the command executes exactly once and both calls return the same token

#### Scenario: Cache expired
- **WHEN** `GetToken()` is called after `acquiredAt + (ttl_seconds - skew_seconds)` has passed
- **THEN** the command executes again and the cache entry is replaced

#### Scenario: Two providers share a token source
- **WHEN** two provider entries declare an identical `command` string
- **THEN** both share a single cache entry and the command executes once per TTL window

#### Scenario: Cache invalidated explicitly
- **WHEN** `Invalidate(auth)` is called for a cached command
- **THEN** the entry is removed and the next `GetToken()` call executes the command again

### Requirement: Token acquisition does not block the message loop
`TokenService` SHALL execute the auth command using `Run()` with the `"Hide"` option and a pid, then poll `ProcessExist()` with a short sleep, in the same manner as `PowerShellTool.ExecuteScript()`. It SHALL NOT use `RunWait`. `Cancel()` SHALL terminate the running process and cause the in-flight call to return without caching a partial result.

#### Scenario: Command runs hidden
- **WHEN** `GetToken()` executes the auth command
- **THEN** no console window appears and the AHK window continues to repaint and respond

#### Scenario: Cancellation during acquisition
- **WHEN** `Cancel()` is called while the auth command is running
- **THEN** the process is terminated, no token is cached, and the call returns without blocking

### Requirement: Output is validated before caching
`TokenService` SHALL treat the command as successful only when stdout, after trimming, is non-empty and begins with `eyJ`. Stdout and stderr SHALL be captured to separate files so CLI warnings on stderr do not corrupt the token.

#### Scenario: Valid token
- **WHEN** the command writes `eyJ0eXAiOiJKV1Qi...` to stdout
- **THEN** the trimmed string is cached and returned

#### Scenario: Command fails or prints a message
- **WHEN** the command writes an error message or nothing to stdout
- **THEN** no token is cached and an error is thrown whose message includes the captured stderr and the configured `login_hint` when present

### Requirement: A 401 response invalidates the cached token
When `LLMClient.Call()` observes a response that indicates HTTP status `401`, it SHALL call `TokenService.Invalidate()` for the provider's `auth` config before surfacing the error, so the next send re-acquires a token.

#### Scenario: Revoked or expired token
- **WHEN** a request returns `401` while a token is cached
- **THEN** the cache entry is removed
- **AND** the next `GetToken()` call executes the auth command again
- **AND** the error is surfaced to the user as an assistant message

### Requirement: Tokens never appear on a process command line
When a curl template contains `{HEADERS_FILE}`, `LLMClient.Call()` SHALL write `Authorization: Bearer <token>` to `temp\auth_headers.txt`, substitute the file path, and delete the file after the request finishes. The token SHALL NOT be placed in the command line for such providers.

#### Scenario: Header file used
- **WHEN** the Azure provider template contains `-H @"{HEADERS_FILE}"`
- **THEN** the command line contains only the path `temp\auth_headers.txt`
- **AND** the token is present in the file at the moment curl runs
- **AND** the file is deleted in the `finally` block

#### Scenario: Provider without the placeholder
- **WHEN** a template does not contain `{HEADERS_FILE}`
- **THEN** no header file is written and substitution behaves exactly as before

### Requirement: Tokens are never written to the traceability log
`TraceabilityService.LogInteraction` SHALL continue to record only the request body, the raw response, timings, and token counts. The auth header SHALL NOT be moved into the request body and header values SHALL NOT be logged.

#### Scenario: Azure request is traced
- **WHEN** a request using `{AUTH_TOKEN}` completes
- **THEN** the `sessions\*.jsonl` entry contains the message body and response
- **AND** the entry contains no substring of the access token

### Requirement: Multiple provider JSON files merge additively
`Providers.Reload()` SHALL read every `providers\*.json` file and merge them. It SHALL NOT skip `providers.json` when other provider files exist. Provider-level keys SHALL be set on first sight and models SHALL merge by name.

#### Scenario: Company file added alongside the default
- **WHEN** `providers\providers.json` and `providers\azure.json` both exist
- **THEN** the providers Map contains all nine default providers plus the Azure provider

#### Scenario: Overriding a single provider key
- **WHEN** a second file redeclares a provider name that already exists
- **THEN** the models from both files are available under that provider name
