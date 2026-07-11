## Context

`LLMClient.Call`'s `finally` block currently contains:
```ahk
} finally {
    ; Cleanup temp files but don't delete audio files
    try {
        ; FileDelete(inputFile)
        ; Only delete JSON response files, not audio files
        ; if (!InStr(selectedLLMType, "gr-audio") = 1) {
        ;    FileDelete(outputFile)
        ; }
    }
    this.pid := 0
}
```

The entire `try { … }` body is commented out. Only `this.pid := 0` executes. The reason for the commented code: temp files used to be cleaned up, but this was disabled (possibly because the response file is read after the curl process exits, which happens before `finally`). The `selectedLLMType` reference inside comments is stale — the variable is defined on line 32 and used on line 66 for an error message, but has no purpose in `finally`.

## Goals / Non-Goals

**Goals:**
- Remove dead commented-out code from the `finally` block

**Non-Goals:**
- No re-enabling of file cleanup (out of scope)
- No other refactoring of `LLMClient`

## Decisions

**Decision: Strip to bare `this.pid := 0`.**

The `try` wrapper serves no purpose — any cleanup logic is already commented out. No further decisions needed.

## Risks / Trade-offs

- None. Dead code deletion — zero runtime impact.
