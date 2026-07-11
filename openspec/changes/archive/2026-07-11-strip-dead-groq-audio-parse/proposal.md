## Why

`GroqAudioProvider.ParseResponse` is dead code. `LLMClient.Call` handles audio responses early — when the provider name is GroqAudio, it creates an `AudioContent` message from the output file and returns before ever calling `ParseResponse`. The method body is a try/catch that attempts to parse a JSON error, then returns `[]`. It's unreachable on success and returns an empty array on the impossible path.

## What Changes

- Replace `GroqAudioProvider.ParseResponse` with a single `throw` clarifying that audio is handled by LLMClient, or delete it to fall through to `BaseProvider.ParseResponse` (which already throws `"Not implemented"`)

## Capabilities

### New Capabilities
<!-- None — dead code removal -->

### Modified Capabilities
<!-- None -->

## Impact

- **Affected code**: `services/LLM/Providers/GroqAudioProvider.ahk`, ~15 lines removed
- **No behavior change**: method was unreachable on success path
