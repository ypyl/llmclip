## MODIFIED Requirements

### Requirement: Clipboard content is parsed by ClipboardParserHelper
`ProcessClipboardCommand` SHALL delegate parsing to `ClipboardParserHelper.Parse()`, which SHALL detect whether the clipboard content is plain text, newline-separated file paths, `file:///` URIs, `CF_HDROP` file paths, or image data.

#### Scenario: Clipboard contains plain text
- **WHEN** clipboard content is a single line of text that does not match any existing file paths
- **THEN** `Parse()` returns an array with one string element containing the text

#### Scenario: Clipboard contains multiple file paths
- **WHEN** clipboard content is newline-separated AND every line is a valid file or directory path
- **THEN** `Parse()` returns an array with one string per path

#### Scenario: Mixed content treated as plain text
- **WHEN** clipboard content is multi-line AND at least one line is NOT a valid path
- **THEN** `Parse()` returns the entire content as a single text string, with line endings normalized to LF

#### Scenario: Clipboard contains CF_HDROP file paths without file URIs
- **WHEN** the `file:///` URI scan produces no results
- **AND** the clipboard contains `CF_HDROP` format data with one or more file paths
- **THEN** `Parse()` SHALL extract each file path via `DragQueryFile` and return them as an array of strings
- **AND** the extraction SHALL handle both ANSI and UTF-16 encoded paths correctly

#### Scenario: CF_HDROP extraction fails gracefully
- **WHEN** the `file:///` URI scan produces no results
- **AND** `CF_HDROP` data is not present or cannot be read (e.g., clipboard locked)
- **THEN** `Parse()` SHALL fall back to returning the plain text clipboard content as a single-element array
- **AND** SHALL NOT display error messages or disrupt the user
