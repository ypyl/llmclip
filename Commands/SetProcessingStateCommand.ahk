#Include ..\ProcessingState.ahk

class SetProcessingStateCommand {
    sessionManager := ""

    __New(sessionManager) {
        this.sessionManager := sessionManager
    }

    Execute(state := ProcessingState.IDLE) {
        this.sessionManager.SetCurrentProcessingState(state)
    }
}
