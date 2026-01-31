#Requires AutoHotkey 2.0

class DeleteMessageCommand {
    sessionManager := ""

    __New(sessionManager) {
        this.sessionManager := sessionManager
    }

    /**
     * Executes the delete message command
     * @param selectedIndices Array of indices to delete from history
     */
    Execute(selectedIndices) {
        if (selectedIndices.Length == 0)
            return

        messages := this.sessionManager.GetCurrentSessionMessages()
        
        ; Remove messages in reverse order to maintain correct indices
        for index in selectedIndices {
            if (index > 1 && index <= messages.Length) { ; Don't include system message
                messages.RemoveAt(index)
            }
        }
    }
}
