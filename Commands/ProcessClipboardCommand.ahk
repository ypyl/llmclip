#Requires AutoHotkey 2.0

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
        context := this.sessionManager.GetCurrentSessionContext()
        addedAny := false

        for item in localTxtFromClipboardArray {
            if !this.sessionManager.IsContentDuplicate(item) {
                context.Push(item)
                addedAny := true
            }
        }

        if (addedAny) {
            this.sessionManager.SetCurrentSessionContext(context)
        }

        return addedAny
    }
}
