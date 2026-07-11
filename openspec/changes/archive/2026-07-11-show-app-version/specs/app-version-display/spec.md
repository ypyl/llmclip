## ADDED Requirements

### Requirement: Version stored in version.txt
The application version SHALL be defined in `version.txt` at the repository root as a single line of text.

#### Scenario: Version file exists
- **WHEN** `version.txt` is present and contains a version string
- **THEN** the app SHALL read and display that version

#### Scenario: Version file missing
- **WHEN** `version.txt` is absent
- **THEN** the app SHALL display "dev" as the version string

### Requirement: Version displayed in top-right corner
The application SHALL display its version string as a small text label in the top-right corner of the main window, visible at all times.

#### Scenario: Version visible at launch
- **WHEN** the main window opens
- **THEN** the version text SHALL be visible at the top-right corner

#### Scenario: Version repositions on resize
- **WHEN** the window is resized
- **THEN** the version label SHALL move to maintain its top-right position
