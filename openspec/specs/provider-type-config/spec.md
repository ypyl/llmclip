## Requirements

### Requirement: Provider type declared in providers.json
Each provider entry in `providers.json` SHALL include a `provider_type` field whose value SHALL be one of `"openai"`, `"ollama"`, `"google"`, or `"audio"`, matching the internal provider class used for API communication.

#### Scenario: Provider type propagated to settings
- **WHEN** a model from a provider with `"provider_type": "openai"` is selected
- **THEN** the settings Map SHALL contain `"provider_type"` → `"openai"`

### Requirement: LLMClient uses provider_type for routing
`LLMClient.GetProvider` SHALL resolve the internal provider by reading `settings["provider_type"]` directly, without matching provider name strings.

#### Scenario: Direct routing via provider_type
- **WHEN** `GetProvider` is called with `settings["provider_type"]` = `"ollama"`
- **THEN** the OllamaProvider instance is returned

#### Scenario: Unknown provider type
- **WHEN** `GetProvider` is called with a `provider_type` not in the providers map
- **THEN** an error is thrown describing the unknown type
