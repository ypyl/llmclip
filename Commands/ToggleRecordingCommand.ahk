class ToggleRecordingCommand {
    recordingService := ""
    sessionManager := ""
    contextManager := ""

    __New(recordingService, sessionManager, contextManager) {
        this.recordingService := recordingService
        this.sessionManager := sessionManager
        this.contextManager := contextManager
    }

    Execute() {
        return this.recordingService.ToggleRecording(this.sessionManager, this.contextManager)
    }
}
