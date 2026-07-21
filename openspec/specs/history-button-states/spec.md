## ADDED Requirements

### Requirement: Delete button disabled when nothing selected

The system SHALL disable the Delete button in the history bar when no message row is selected in the history list.

#### Scenario: No selection disables Delete

- **WHEN** the history list has items but no row is selected
- **THEN** the Delete button SHALL be disabled

#### Scenario: Selection enables Delete

- **WHEN** a user clicks on a message row in the history list
- **THEN** the Delete button SHALL become enabled

#### Scenario: List rebuild clears selection and disables Delete

- **WHEN** `UpdateChatHistoryView()` rebuilds the history list
- **THEN** the Delete button SHALL be disabled (selection is lost on rebuild)

### Requirement: Previous button reflects branch position

The system SHALL disable the Previous (`<`) button when the current history branch is the first branch, and SHALL hide it entirely when there is only one branch.

#### Scenario: Single branch hides Previous

- **WHEN** the session has only one history branch (`1/1`)
- **THEN** the Previous button SHALL be hidden

#### Scenario: First branch disables Previous

- **WHEN** the session has multiple branches and the current branch is the first (`1/N` where N > 1)
- **THEN** the Previous button SHALL be visible but disabled

#### Scenario: Non-first branch enables Previous

- **WHEN** the current branch is not the first (`M/N` where M > 1)
- **THEN** the Previous button SHALL be visible and enabled

### Requirement: Next button reflects branch position

The system SHALL disable the Next (`>`) button when the current history branch is the last branch, and SHALL hide it entirely when there is only one branch.

#### Scenario: Single branch hides Next

- **WHEN** the session has only one history branch (`1/1`)
- **THEN** the Next button SHALL be hidden

#### Scenario: Last branch disables Next

- **WHEN** the current branch is the last (`N/N` where N > 1)
- **THEN** the Next button SHALL be visible but disabled

#### Scenario: Non-last branch enables Next

- **WHEN** the current branch is not the last (`M/N` where M < N)
- **THEN** the Next button SHALL be visible and enabled

### Requirement: Button states recalculated on state changes

The system SHALL recalculate all history button states after any event that changes history state: list rebuild, item selection, and branch navigation.

#### Scenario: States updated after list rebuild

- **WHEN** `UpdateChatHistoryView()` completes
- **THEN** all history button states (Delete, Previous, Next) SHALL reflect the current history state

#### Scenario: States updated after selection change

- **WHEN** a user selects or deselects a row in the history list
- **THEN** the Delete button state SHALL reflect whether a row is selected
- **AND** Previous/Next button states SHALL remain unchanged (selection does not affect branch position)

#### Scenario: States updated after branch navigation

- **WHEN** the user navigates to a different history branch via Previous or Next
- **THEN** Previous and Next button states SHALL reflect the new branch position

### Requirement: View exposes setter methods following existing pattern

The `HistoryView` SHALL expose individual setter methods for each button state, following the existing `SetClearHistoryButtonEnabled` pattern.

#### Scenario: Setter methods follow existing convention

- **WHEN** `HistoryView` is inspected
- **THEN** it SHALL expose `SetDeleteButtonEnabled(enabled)`, `SetPrevButtonEnabled(enabled)`, `SetNextButtonEnabled(enabled)`, `SetPrevButtonVisible(visible)`, and `SetNextButtonVisible(visible)` methods
- **AND** each method SHALL set the corresponding button's `Enabled` or `Visible` property
