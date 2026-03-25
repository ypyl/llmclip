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
     * User messages with context produce a 📎 context row before the message row.
     * Each item includes messageIndex, isThinking, and isContext for caller routing.
     * @returns Array of objects {roleEmoji, contentText, duration, tokens, messageIndex, isThinking, isContext}
     */
    Execute() {
        allMessages := this.sessionManager.GetCurrentSessionMessages()
        items := []

        for i, msg in allMessages {
            hasThinking := msg.AdditionalProperties.Has("thinking") && msg.AdditionalProperties["thinking"] != ""
            hasContext := msg.Role == "user" && msg.AdditionalProperties.Has("hasContext") && msg.AdditionalProperties["hasContext"]

            if (hasThinking) {
                ; Insert synthetic thinking row first
                thinkingItem := MessagePresentationService.GetThinkingListViewItem(msg)
                thinkingItem.messageIndex := i
                thinkingItem.isThinking := true
                thinkingItem.isContext := false
                items.Push(thinkingItem)
            }

            if (hasContext) {
                ; Insert synthetic context row before user message
                ctxItem := MessagePresentationService.GetContextListViewItem(msg)
                ctxItem.messageIndex := i
                ctxItem.isThinking := false
                ctxItem.isContext := true
                items.Push(ctxItem)
            }

            ; Insert the actual message row
            item := MessagePresentationService.GetListViewItem(msg)
            item.messageIndex := i
            item.isThinking := false
            item.isContext := false
            items.Push(item)
        }

        return items
    }
}
