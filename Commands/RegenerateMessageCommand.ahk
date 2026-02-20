class RegenerateMessageCommand {
    sessionManager := ""
    
    __New(sessionManager) {
        this.sessionManager := sessionManager
    }
    
    Execute(messageIndex) {
        if (messageIndex <= 0)
            return ""

        messages := this.sessionManager.GetCurrentSessionMessages()
        if (messageIndex >= messages.Length)
            return ""

        selectedMsg := messages[messageIndex]
        if (selectedMsg.Role != "user")
            return ""

        messageText := this.sessionManager.GetUserMessageTextWithoutContext(selectedMsg)
        
        if (this.sessionManager.CreateHistoryBranch(messageIndex - 1))
            return messageText
        
        return ""
    }
}
