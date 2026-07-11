## REMOVED Requirements

### Requirement: GroqAudioProvider.ParseResponse parses error JSON
**Reason**: Method unreachable on success path — LLMClient handles audio responses before `ParseResponse` is called. BaseProvider's default `throw` covers the impossible error path.
**Migration**: None. Falls through to `BaseProvider.ParseResponse` which throws `"Not implemented"`.
