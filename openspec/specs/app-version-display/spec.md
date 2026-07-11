## Requirements

### Requirement: Version stored in version.txt
The application version SHALL be defined in `version.txt` at the repository root as a single line of text.

#### Scenario: Version file exists
- **WHEN** `version.txt` is present and contains a version string
- **THEN** the app SHALL read and display that version

#### Scenario: Version file missing
- **WHEN** `version.txt` is absent
- **THEN** the app SHALL display "dev" as the version string

### Requirement: Version displayed in title bar
The application SHALL display its version string in the window title bar, prefixed with "LLMClip v".

#### Scenario: Version visible at launch
- **WHEN** the main window opens
- **THEN** the title bar SHALL show "LLMClip v" followed by the version from `version.txt`

#### Scenario: Title bar persists across sessions
- **WHEN** the application is running
- **THEN** the version SHALL remain visible in the title bar regardless of window size or WebView content
