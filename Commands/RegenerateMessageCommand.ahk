#Requires AutoHotkey 2.0

/**
 * Command to handle message regeneration or editing.
 * UI-agnostic logic for modifying session history.
 */
class RegenerateMessageCommand {
    sessionManager := ""
    configManager := ""

    __New(sessionManager, configManager) {
        this.sessionManager := sessionManager
        this.configManager := configManager
    }

    /**
     * Executes the regeneration/edit logic.
     * @param focusedRow The index of the message in the history.
     * @param promptText The current text in the prompt editor.
     * @param getCheckedImagesCallback A callback to get images from the UI layer.
     * @returns {Object} { status: "load_to_prompt" | "sent" | "none", text: string }
     */
    Execute(focusedRow, promptText, getCheckedImagesCallback) {
        if (focusedRow <= 0) {
            return { status: "none" }
        }

        messages := this.sessionManager.GetCurrentSessionMessages()
        selectedMsg := messages[focusedRow]

        if (selectedMsg.Role != "user") {
            return { status: "none" }
        }

        if (promptText == "") {
            ; Case 1: Load message content into prompt for editing
            return { 
                status: "load_to_prompt", 
                text: this.sessionManager.GetUserMessageTextWithoutContext(selectedMsg) 
            }
        }

        ; Case 2: Edit Mode Logic
        images := getCheckedImagesCallback()
        newContent := this.sessionManager.BuildUserMessage(promptText, images)

        ; Check if this is the first user message with context
        isFirstUserMsg := false
        for i, msg in messages {
            if (msg.Role == "user") {
                isFirstUserMsg := (msg == selectedMsg)
                break
            }
        }

        ; If first user message with context, preserve the context
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

        ; Truncate history after this message
        if (this.sessionManager.TruncateMessages(focusedRow)) {
            return { status: "sent" }
        }

        return { status: "none" }
    }
}
