## MODIFIED Requirements

### Requirement: Clipboard content is parsed by ClipboardParserHelper
`ProcessClipboardCommand` SHALL delegate parsing to `ClipboardParserHelper.Parse()`, which SHALL detect whether the clipboard content is plain text, newline-separated file paths, `file:///` URIs, bare Windows drive-letter paths, or image data.

#### Scenario: Clipboard contains plain text
- **WHEN** clipboard content is a single line of text that does not match any existing file paths
- **THEN** `Parse()` returns an array with one string element containing the text

#### Scenario: Clipboard contains multiple file paths
- **WHEN** clipboard content is newline-separated AND every line is a valid file or directory path
- **THEN** `Parse()` returns an array with one string per path

#### Scenario: Mixed content treated as plain text
- **WHEN** clipboard content is multi-line AND at least one line is NOT a valid path
- **THEN** `Parse()` returns the entire content as a single text string, with line endings normalized to LF

#### Scenario: Clipboard contains bare drive-letter paths without file URIs
- **WHEN** the `file:///` URI scan produces no results
- **AND** the raw clipboard bytes contain a Windows drive-letter path (e.g., `C:\Users\...`)
- **THEN** `Parse()` SHALL extract the path by locating the drive-letter pattern and validating the candidate via `FileExist`/`DirExist`
- **AND** SHALL return the valid path(s) as an array of strings

#### Scenario: Drive-letter extraction fails gracefully
- **WHEN** the `file:///` URI scan produces no results
- **AND** no valid drive-letter path can be extracted from the raw data
- **THEN** `Parse()` SHALL fall back to returning the plain text clipboard content as a single-element array
- **AND** SHALL NOT display error messages or disrupt the user
