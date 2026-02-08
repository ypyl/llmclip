#Requires AutoHotkey 2.0

class GetHistoryListItemsCommand {
    sessionManager := ""
    messagePresentationService := ""

    __New(sessionManager, messagePresentationService) {
        this.sessionManager := sessionManager
        this.messagePresentationService := messagePresentationService
    }

    /**
     * Executes the command to get formatted history items for the ListView.
     * @returns Array of objects {roleEmoji, contentText, duration, tokens}
     */
    Execute() {
        allMessages := this.sessionManager.GetCurrentSessionMessages()
        items := []
        
        for msg in allMessages {
            item := this.messagePresentationService.GetListViewItem(msg)
            items.Push(item)
        }
        
        return items
    }
}
