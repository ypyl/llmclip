#Requires AutoHotkey 2.0

class ChangeAnswerSizeCommand {
    sessionManager := ""

    __New(sessionManager) {
        this.sessionManager := sessionManager
    }

    Execute(size) {
        this.sessionManager.SetAnswerSize(size)
    }
}
