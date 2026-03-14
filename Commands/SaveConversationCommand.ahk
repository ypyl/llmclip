#Requires AutoHotkey 2.0

class SaveConversationCommand {
    sessionManager := ""

    __New(sessionManager) {
        this.sessionManager := sessionManager
    }

    /**
     * Executes the save conversation command
     * @param filePath The path where the conversation should be saved
     */
    Execute(filePath) {
        if (filePath == "")
            return

        ; Get the session state string
        conversationState := this.sessionManager.ExportSessionState()
        jsonStr := JSON.Stringify(conversationState)

        ; Use file service to write to disk
        FileService.WriteText(filePath, jsonStr)
    }
}
