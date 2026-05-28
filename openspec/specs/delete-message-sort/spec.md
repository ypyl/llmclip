# delete-message-sort

DeleteMessageCommand defensively sorts its input indices in descending order before removal, so the command works correctly regardless of input order.

## Requirements

### Requirement: DeleteMessageCommand sorts indices before removal
`DeleteMessageCommand.Execute()` SHALL sort the `selectedIndices` array in descending order before iterating and removing messages, so that removals do not shift the positions of remaining indices to be deleted.

#### Scenario: Unsorted indices are handled correctly
- **WHEN** `Execute([3, 7, 5])` is called
- **THEN** the command sorts to `[7, 5, 3]` before processing
- **AND** all three messages at indices 3, 5, and 7 are removed correctly

#### Scenario: Already-sorted indices are unchanged
- **WHEN** `Execute([7, 5, 3])` is called (already descending)
- **THEN** the sort produces `[7, 5, 3]` (no-op)
- **AND** all three messages are removed correctly

#### Scenario: Empty array
- **WHEN** `Execute([])` is called
- **THEN** no sort is performed and no messages are removed
