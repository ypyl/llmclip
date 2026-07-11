## Why

`LLMClient.Call` has a `finally` block containing a commented-out `try { … }` body (3 lines of dead comments) and a stale comment about temp file cleanup that was disabled. The only live code in the `finally` block is `this.pid := 0` — removing the dead comments reduces noise and potential confusion. The `selectedLLMType` variable referenced in the dead comment remains in use elsewhere (line 66 error message), so it stays.

## What Changes

- Remove the commented-out `try` block and its `; Cleanup temp files` comment from the `finally` block in `LLMClient.Call`
- The `finally` block reduces to just `this.pid := 0`

## Capabilities

### New Capabilities
<!-- None — dead code removal, no behavior change -->

### Modified Capabilities
<!-- None -->

## Impact

- **Affected code**: `services/LLM/LLMClient.ahk`, ~8 lines removed
- **No behavior change**: cleanup was already disabled
- **No caller changes**
