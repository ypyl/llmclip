
class ProcessClipboardCommand {
    recordingService := ""
    clipboardParser := ""
    sessionManager := ""

    __New(recordingService, clipboardParser, sessionManager) {
        this.recordingService := recordingService
        this.clipboardParser := clipboardParser
        this.sessionManager := sessionManager
    }

    Execute() {
        if (!this.recordingService.isRecording) {
            return false
        }

        localTxtFromClipboardArray := this.clipboardParser.Parse()
        return this.sessionManager.AddContextItems(localTxtFromClipboardArray)
    }
}
