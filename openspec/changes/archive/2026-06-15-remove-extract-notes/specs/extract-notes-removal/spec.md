## REMOVED Requirements

### Requirement: Extract Notes from conversation history
The system SHALL NOT provide an "Extract Notes" feature that invokes an LLM call to summarize learnings from the current conversation.

**Reason**: Unused feature — dead code that adds maintenance burden with no user adoption.
**Migration**: None required. No user workflows depend on this feature.

#### Scenario: History menu does not contain Extract Notes
- **WHEN** user opens the History submenu in the menu bar
- **THEN** the menu SHALL NOT contain an "Extract Notes" item

#### Scenario: ProcessingState has no EXTRACTING constant
- **WHEN** any code references `ProcessingState.EXTRACTING`
- **THEN** the reference SHALL fail to resolve

#### Scenario: ExtractLearningsCommand does not exist
- **WHEN** any code instantiates `ExtractLearningsCommand`
- **THEN** the instantiation SHALL fail because the class file has been deleted
