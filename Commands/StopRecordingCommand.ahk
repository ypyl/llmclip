#Requires AutoHotkey 2.0

class StopRecordingCommand {
    recordingService := ""
    sessionManager := ""
    contextManager := ""

    __New(recordingService, sessionManager, contextManager) {
        this.recordingService := recordingService
        this.sessionManager := sessionManager
        this.contextManager := contextManager
    }

    Execute() {
        return this.recordingService.StopRecording(this.sessionManager, this.contextManager)
    }
}
