
class ProcessClipboardCommand {
    recordingService := ""
    sessionManager := ""

    __New(recordingService, sessionManager) {
        this.recordingService := recordingService
        this.sessionManager := sessionManager
    }

    Execute() {
        if (!this.recordingService.isRecording) {
            return false
        }

        localTxtFromClipboardArray := ClipboardParserService.Parse()
        return this.sessionManager.AddContextItems(localTxtFromClipboardArray)
    }
}
