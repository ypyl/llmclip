## Context

`LLMClient.Call` routes audio providers differently: when `providerName` is GroqAudio, it writes the response to a file, creates an `AudioContent` message, and returns early — `ParseResponse` is never called. The only theoretical path to `ParseResponse` would be an error case where the provider ISN'T detected as audio, which can't happen in practice since the `GetProvider` routing sends all audio to this class.

## Goals / Non-Goals

**Goals:**
- Remove unreachable `ParseResponse` method

**Non-Goals:**
- No refactoring of LLMClient audio handling

## Decisions

**Decision: Delete `ParseResponse` entirely, let BaseProvider's throw handle any edge case.**

`BaseProvider.ParseResponse` throws `Error("Not implemented")`. If somehow audio parsing is called, this is a clearer error than returning `[]`. No need for a wrapper.

## Risks / Trade-offs

- None. Dead code removal — zero runtime impact.
