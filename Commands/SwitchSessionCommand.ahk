#Requires AutoHotkey 2.0

class SwitchSessionCommand {
    sessionManager := ""

    __New(sessionManager) {
        this.sessionManager := sessionManager
    }

    Execute(sessionIndex) {
        this.sessionManager.SwitchSession(sessionIndex)
    }
}
