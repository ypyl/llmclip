class SessionManager {
    currentSessionIndex := 1
    MAX_SESSIONS := 3
    sessionNames := ["Session 1", "Session 2", "Session 3"]
    sessionMessages := []
    sessionContexts := []

    __New(appSettings) {
        this.appSettings := appSettings

        ; Initialize session arrays
        Loop this.MAX_SESSIONS {
            this.sessionMessages.Push([{
                role: "system",
                content: this.appSettings.GetSystemPromptValue()
            }])
            this.sessionContexts.Push([])
        }
    }

    GetCurrentSessionMessages() {
        return this.sessionMessages[this.currentSessionIndex]
    }

    GetCurrentSessionContext() {
        return this.sessionContexts[this.currentSessionIndex]
    }

    SetCurrentSessionContext(newContext) {
        this.sessionContexts[this.currentSessionIndex] := newContext
    }

    SwitchSession(newIndex) {
        if (newIndex > 0 && newIndex <= this.MAX_SESSIONS) {
            this.currentSessionIndex := newIndex
            return true
        }
        return false
    }

    ResetCurrentSession() {
        this.ClearCurrentMessages()
        this.ClearCurrentContext()
    }

    ClearCurrentMessages() {
        this.sessionMessages[this.currentSessionIndex] := [{
            role: "system",
            content: this.appSettings.GetDefaultSystemPrompt()
        }]
    }

    ClearCurrentContext() {
        this.sessionContexts[this.currentSessionIndex] := []
    }

    DeleteMessage(index) {
        if (index > 1 && index <= this.sessionMessages[this.currentSessionIndex].Length) {
            this.sessionMessages[this.currentSessionIndex].RemoveAt(index)
            return true
        }
        return false
    }
}
