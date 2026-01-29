#Requires AutoHotkey 2.0

class LoadConversationCommand {
    sessionManager := ""
    fileService := ""

    __New(sessionManager, fileService) {
        this.sessionManager := sessionManager
        this.fileService := fileService
    }

    /**
     * Executes the load conversation command
     * @param filePath The path where the conversation should be loaded from
     */
    Execute(filePath) {
        if (filePath == "")
            return

        ; Use file service to read from disk
        fileContent := this.fileService.ReadText(filePath)
        
        ; Parse JSON and import state
        state := JSON.Load(fileContent)
        this.sessionManager.ImportSessionState(state)
    }
}
