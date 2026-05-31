## Why

`SendBatchToLLMCommand` calls `this.contextManager.GetLabelFromContextItem(item)` at line ~50, but `ContextManager` has no such method. It exists only on `ContextPresentationService`. Attempting to use batch mode will crash with a method-not-found error at runtime. This was discovered during the architecture audit (see `CODE-AUDIT.md`, Issue 1).

## What Changes

- Fix the nonexistent method call in `SendBatchToLLMCommand` by injecting `ContextPresentationService` and calling its `GetLabelFromContextItem()` method instead
- Add `ContextPresentationService` as a constructor dependency of `SendBatchToLLMCommand`
- Update `App.ahk` wiring to pass `cps` (already instantiated) into `SendBatchToLLMCommand`

## Capabilities

### Modified Capabilities
- **batch-mode**: Item label generation in batch responses now correctly uses `ContextPresentationService.GetLabelFromContextItem()` instead of calling a nonexistent method on `ContextManager`. No requirement change — this is a bug fix that restores intended behavior.

## Impact

- **Affected layers**: Command, Service, Composition Root
- `commands/SendBatchToLLMCommand.ahk` — change method call target and add constructor parameter
- `App.ahk` — pass `cps` into `SendBatchToLLMCommand` constructor
- No API changes, no breaking changes
