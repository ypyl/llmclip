# compression-service

## REMOVED Requirements

### Requirement: Compression service accepts pre-extracted data

**Reason**: The entire History → Compress feature is being removed. `LLMService.CompressHistory()` is dead code with no callers.

**Migration**: No migration needed. The feature was unused. All service-layer compression methods (in `LLMService`, `SessionManager`, `ConfigurationService`) are removed alongside this spec.

#### Scenario: Compression with valid inputs

- **WHEN** (removed — feature deleted)
- **THEN** (removed — feature deleted)

#### Scenario: Compression with insufficient messages

- **WHEN** (removed — feature deleted)
- **THEN** (removed — feature deleted)

#### Scenario: Compression with empty conversation text

- **WHEN** (removed — feature deleted)
- **THEN** (removed — feature deleted)

### Requirement: Compression command passes extracted data to service

**Reason**: `CompressHistoryCommand` is deleted as part of the compress feature removal. No other command calls `LLMService.CompressHistory()`.

**Migration**: No migration needed.

#### Scenario: Successful compression flow

- **WHEN** (removed — feature deleted)
- **THEN** (removed — feature deleted)
