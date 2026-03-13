#Requires AutoHotkey 2.0

class SaveEditedMessageCommand {
    sessionManager := ""

    __New(sessionManager) {
        this.sessionManager := sessionManager
    }

    Execute(index, newText) {
        return this.sessionManager.UpdateMessageText(index, newText)
    }
}
