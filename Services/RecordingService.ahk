
class RecordingService {
    isRecording := false
    
    StartRecording() {
        if (!this.isRecording) {
            this.isRecording := true
            return true
        }
        return false
    }

    StopRecording(sessionManager := "", contextManager := "") {
        if (this.isRecording) {
            this.isRecording := false

            if (sessionManager && contextManager) {
                recordedText := ""
                context := sessionManager.GetCurrentSessionContext()
                for item in context {
                    recordedText .= contextManager.GetTextFromContextItem(item)
                }
                A_Clipboard := recordedText
            }
            return true
        }
        return false
    }

    ToggleRecording(sessionManager, contextManager) {
        if (this.isRecording) {
            return this.StopRecording(sessionManager, contextManager)
        } else {
            return this.StartRecording()
        }
    }
}
