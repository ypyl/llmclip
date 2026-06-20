## ADDED Requirements

### Requirement: User can start and stop clipboard recording

The system SHALL allow the user to toggle a recording mode that captures clipboard changes. When recording is active, clipboard content is accumulated as context items. When recording stops, the accumulated context is placed on the clipboard.

#### Scenario: Start recording via tray menu
- **WHEN** recording is not active AND user clicks "Start Recording" in the tray menu
- **THEN** the system enters recording mode AND the tray icon changes to indicate recording state AND the "Start Recording" menu item is disabled

#### Scenario: Stop recording via tray menu
- **WHEN** recording is active AND user clicks "Stop Recording" in the tray menu
- **THEN** the system exits recording mode AND accumulated context is copied to the clipboard AND the tray icon reverts to idle state

#### Scenario: Toggle recording via tray left-click
- **WHEN** user left-clicks the tray icon
- **THEN** recording toggles: starts if idle, stops if recording and window is visible, or shows the window if recording and hidden

#### Scenario: Toggle recording via hotkey
- **WHEN** recording is not active AND user presses F6
- **THEN** recording starts

#### Scenario: Stop recording via GUI button while window visible
- **WHEN** recording is active AND the main window is visible AND user clicks the Record/Stop button
- **THEN** recording stops AND accumulated context is copied to the clipboard

### Requirement: Recording state is reflected in UI

The system SHALL keep all UI elements synchronized with the current recording state.

#### Scenario: Tray icon reflects recording state
- **WHEN** recording starts OR stops
- **THEN** the tray icon, tooltip, and menu item enable/disable states reflect the new state

#### Scenario: Record button text reflects state
- **WHEN** the main window is visible AND recording state changes
- **THEN** the record button text shows "Stop" when recording and "Record" when idle

### Requirement: Recording commands delegate to RecordingService via the Command layer

All recording state mutations SHALL flow through Commands to RecordingService. Controllers MUST NOT mutate recording state directly.

#### Scenario: Start recording follows architecture
- **WHEN** any UI trigger starts recording
- **THEN** a StartRecordingCommand is executed, which calls RecordingService.StartRecording()

#### Scenario: Stop recording follows architecture
- **WHEN** any UI trigger stops recording
- **THEN** a StopRecordingCommand is executed, which calls RecordingService.StopRecording()
