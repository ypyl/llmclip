## Why

`ConfigurationService.SetToolEnabled()` writes tool enable/disable choices directly into the in-memory providers cache — the same cache that `Reload()` rebuilds from `providers.json`. This means user tool preferences are silently wiped whenever settings are reloaded (via menu, after creating a prompt, or on app restart). The providers cache mixes two concerns: immutable defaults from JSON and mutable user choices. Separating them ensures tool preferences survive reloads, restarts, and configuration changes.

## What Changes

- `ConfigurationService` gains a per-model `toolOverrides` Map that stores user's explicit enable/disable choices, separate from provider defaults.
- `IsToolEnabled()` reads from overrides first, falling back to provider defaults from `providers.json`.
- `SetToolEnabled()` writes to `toolOverrides` instead of mutating the providers cache.
- `SaveStateOnExitCommand` serializes `toolOverrides` into `state.json` alongside existing preferences (`modelIndex`, `systemPromptIndex`, `answerSize`, `batchMode`).
- `LoadStateOnStartCommand` restores `toolOverrides` from `state.json` on startup.
- `Reload()` no longer resets tool preferences — it only refreshes provider defaults.

## Capabilities

### New Capabilities
- `tool-persistence`: Tool enable/disable preferences are stored per-model in `state.json`, survive configuration reloads and app restarts, and are merged with provider defaults at read time.

### Modified Capabilities
<!-- None — existing behavior is preserved, just made durable -->

## Impact

- **Modified**: `Services\Configuration\ConfigurationService.ahk` — new `toolOverrides` Map, updated `IsToolEnabled()` and `SetToolEnabled()`
- **Modified**: `Commands\SaveStateOnExitCommand.ahk` — serialize toolOverrides
- **Modified**: `Commands\LoadStateOnStartCommand.ahk` — restore toolOverrides
- **No changes** to controllers, views, providers.json, or any other files
