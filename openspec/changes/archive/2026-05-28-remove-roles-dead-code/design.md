## Context

`Roles` class filters which system prompts are visible to each LLM provider. It was disabled via `ROLES_DISABLED := true` at some point, making all prompts visible to all providers. The class and its JSON file loading remain in the codebase as dead weight.

## Goals / Non-Goals

**Goals:**
- Remove the `Roles` class and all references
- Simplify `GetVisiblePrompts()` to remove the dead `rolesManager` call
- Zero behavioral change

## Decisions

### Decision: Delete the file rather than comment out

The class is 30 lines, has been disabled for a long time, and has no callers outside `ConfigurationService`. Deleting it is cleaner than leaving commented-out code.

## Risks / Trade-offs

**Risk**: Someone may want to re-enable role-based filtering later.  
→ **Mitigation**: `roles.json` file is left in place. The deleted code can be retrieved from git history. The feature was explicitly marked "DISABLED" in comments — this was an intentional, permanent disable, not a temporary flag.
