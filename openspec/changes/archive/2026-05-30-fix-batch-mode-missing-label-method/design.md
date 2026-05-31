## Context

`SendBatchToLLMCommand` iterates over checked context items and calls `this.contextManager.GetLabelFromContextItem(item)` to produce a label for each item. This method does not exist on `ContextManager` — it lives on `ContextPresentationService`. Batch mode is unreachable without crashing.

The fix is straightforward: inject the correct dependency. `ContextPresentationService` is already instantiated in `App.ahk` as `cps` and already injected into `ContextViewController`. It just needs to be passed into `SendBatchToLLMCommand` as well.

## Goals / Non-Goals

**Goals:**
- Fix the crash so `SendBatchToLLMCommand` uses `ContextPresentationService.GetLabelFromContextItem()` correctly
- Keep the change minimal — only the dependency and the call site change

**Non-Goals:**
- Refactoring `ContextManager` or `ContextPresentationService` APIs
- Adding or removing methods from either service
- Changing batch mode behavior beyond the bug fix

## Decisions

### Inject `ContextPresentationService` into `SendBatchToLLMCommand`

**Choice:** Add `ContextPresentationService` as a constructor parameter of `SendBatchToLLMCommand` and call `this.cps.GetLabelFromContextItem(item)` instead of `this.contextManager.GetLabelFromContextItem(item)`.

**Alternatives considered:**

| Option | Pros | Cons |
|--------|------|------|
| **A: Inject cps** (chosen) | Clean DI. No code duplication. Consistent with existing patterns (`cps` already injected elsewhere). | Adds one new dependency to the command. |
| B: Inline label generation in command | No new dependency. | Duplicates label-generation logic from `ContextPresentationService`. Would drift if presentation logic changes. |
| C: Add method to `ContextManager` | Command keeps single dependency. | Violates separation of concerns — `ContextManager` handles data access (text extraction, type checks), not presentation (emoji icons, truncation). |

**Rationale for Option A:** The command already holds multiple service dependencies (`SessionManager`, `ConfigManager`, `LLMService`, `ContextManager`). Adding `ContextPresentationService` follows the existing DI pattern exactly. The label-generation logic stays in one place. No architectural boundary is crossed — Commands are allowed to call Services.

### Call `GetLabelFromContextItem` as a static method (existing behavior)

`ContextPresentationService.GetLabelFromContextItem()` is already a static-like instance method on a service that has no mutable state. The command will call it via `this.cps.GetLabelFromContextItem(item)` — same pattern as `ContextViewController` already uses.

## Risks / Trade-offs

- **Risk:** `SendBatchToLLMCommand` now has 5 dependencies, which may feel heavy. → **Mitigation:** Each dependency serves a distinct purpose. This is a simple coordination command, not God-object territory.
- **Risk:** If `ContextPresentationService` is not available in all batch-mode code paths, the crash persists. → **Mitigation:** `cps` is created unconditionally in `App.ahk` before any commands. No conditional path can skip it.
