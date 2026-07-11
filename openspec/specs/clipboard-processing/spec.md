## Requirements

### Requirement: Clipboard changes trigger context capture during recording
The system SHALL detect clipboard changes via `OnClipboardChange` and, when recording is active, parse the clipboard content and add it as a context item. If recording is not active, clipboard changes SHALL be ignored.

#### Scenario: Text copied while recording
- **WHEN** recording is active AND the user copies plain text to the clipboard
- **THEN** the text SHALL be added as a new `ContextItem` to the current session context
- **AND** the item SHALL be checked by default

#### Scenario: File paths copied while recording
- **WHEN** recording is active AND the clipboard contains one or more valid file/folder paths (each item passes `FileExist` or `DirExist`)
- **THEN** each valid path SHALL be added as a separate `ContextItem`
- **AND** each item SHALL be checked by default

#### Scenario: Clipboard change while not recording
- **WHEN** recording is NOT active
- **THEN** clipboard changes SHALL NOT add any context items

### Requirement: Clipboard content is parsed by ClipboardParserHelper
`ProcessClipboardCommand` SHALL delegate parsing to `ClipboardParserHelper.Parse()`, which SHALL detect whether the clipboard content is plain text, newline-separated file paths, or image data.

#### Scenario: Clipboard contains plain text
- **WHEN** clipboard content is a single line of text that does not match any existing file paths
- **THEN** `Parse()` returns an array with one string element containing the text

#### Scenario: Clipboard contains multiple file paths
- **WHEN** clipboard content is newline-separated AND every line is a valid file or directory path
- **THEN** `Parse()` returns an array with one string per path

#### Scenario: Mixed content treated as plain text
- **WHEN** clipboard content is multi-line AND at least one line is NOT a valid path
- **THEN** `Parse()` returns the entire content as a single text string, with line endings normalized to LF

### Requirement: Duplicate context items are skipped
`SessionManager.AddContextItems` SHALL skip any item whose value already exists in the current session context, returning `true` only if at least one new item was added.

#### Scenario: Duplicate text skipped
- **WHEN** context already contains a `ContextItem` with value `"example.txt"`
- **AND** the same value is parsed from clipboard again
- **THEN** the duplicate SHALL NOT be added to context

#### Scenario: Unique item added
- **WHEN** context does not contain the parsed value
- **THEN** the item SHALL be appended to the context array as a `ContextItem` with `Checked := true`
