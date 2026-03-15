#Requires AutoHotkey 2.0

class GetHistoryListItemsCommand {
    sessionManager := ""

    __New(sessionManager) {
        this.sessionManager := sessionManager
    }

    /**
     * Executes the command to get formatted history items for the ListView.
     * Messages with thinking content produce two rows: a 💭 thinking row first,
     * then the actual message row.
     * Each item includes messageIndex and isThinking for caller routing.
     * @returns Array of objects {roleEmoji, contentText, duration, tokens, messageIndex, isThinking}
     */
    Execute() {
        allMessages := this.sessionManager.GetCurrentSessionMessages()
        items := []

        for i, msg in allMessages {
            hasThinking := msg.AdditionalProperties.Has("thinking") && msg.AdditionalProperties["thinking"] != ""

            if (hasThinking) {
                ; Insert synthetic thinking row first
                thinkingItem := MessagePresentationService.GetThinkingListViewItem(msg)
                thinkingItem.messageIndex := i
                thinkingItem.isThinking := true
                items.Push(thinkingItem)
            }

            ; Insert the actual message row
            item := MessagePresentationService.GetListViewItem(msg)
            item.messageIndex := i
            item.isThinking := false
            items.Push(item)
        }

        return items
    }
}
