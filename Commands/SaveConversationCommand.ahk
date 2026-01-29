#Requires AutoHotkey 2.0

class SaveConversationCommand {
    sessionManager := ""
    fileService := ""

    __New(sessionManager, fileService) {
        this.sessionManager := sessionManager
        this.fileService := fileService
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
        this.fileService.WriteText(filePath, jsonStr)
    }
}
