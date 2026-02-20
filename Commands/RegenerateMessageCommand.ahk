class RegenerateMessageCommand {
    sessionManager := ""
    
    __New(sessionManager) {
        this.sessionManager := sessionManager
    }
    
    Execute(focusedRow, promptText, images) {
        if (focusedRow <= 0) {
            return { status: "none" }
        }

        messages := this.sessionManager.GetCurrentSessionMessages()
        selectedMsg := messages[focusedRow]

        if (selectedMsg.Role != "user") {
            return { status: "none" }
        }

        if (promptText == "") {
            return {
                status: "load_to_prompt",
                text: this.sessionManager.GetUserMessageTextWithoutContext(selectedMsg)
            }
        }

        newContent := this.sessionManager.BuildUserMessage(promptText, images)

        isFirstUserMsg := false
        for i, msg in messages {
            if (msg.Role == "user") {
                isFirstUserMsg := (msg == selectedMsg)
                break
            }
        }

        if (isFirstUserMsg && selectedMsg.AdditionalProperties.Has("hasContext")
            && selectedMsg.AdditionalProperties["hasContext"]
            && selectedMsg.Contents.Length > 0 && (selectedMsg.Contents[1] is TextContent)) {
            contextText := selectedMsg.Contents[1]
            newContentWithContext := [contextText]
            for part in newContent {
                newContentWithContext.Push(part)
            }
            selectedMsg.Contents := newContentWithContext
        } else {
            selectedMsg.Contents := newContent
        }

        if (this.sessionManager.TruncateMessages(focusedRow)) {
            return { status: "sent" }
        }

        return { status: "none" }
    }
}