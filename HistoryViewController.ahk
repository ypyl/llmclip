#Requires AutoHotkey 2.0

class HistoryViewController {
    SessionManagerValue := ""
    WebViewManagerValue := ""
    MyGui := ""

    AppSettingsValue := ""

    __New(sessionManager, webViewManager, appSettings) {
        this.SessionManagerValue := sessionManager
        this.WebViewManagerValue := webViewManager
        this.AppSettingsValue := appSettings
    }

    SetGui(gui) {
        this.MyGui := gui
    }

    UpdateChatHistoryView(*) {
        if (!this.MyGui)
            return

        messages := this.SessionManagerValue.GetCurrentSessionMessagesAsStrings()
        chatHistory := this.MyGui["ChatHistory"]
        chatHistory.Delete()
        for msg in messages {
            duration := msg.HasOwnProp("duration") ? Round(msg.duration, 2) . "s" : ""
            tokens := msg.HasOwnProp("tokens") ? msg.tokens : ""
            chatHistory.Add(, msg.role, SubStr(msg.content, 1, 70) (StrLen(msg.content) > 70 ? "..." : ""), duration,
            tokens)
        }
        this.MyGui["ChatMessageActionButton"].Visible := false  ; Hide the Run Tool button
        if (chatHistory.GetCount() > 0) {
            chatHistory.Modify(chatHistory.GetCount(), "Vis")  ; Scroll to bottom
        }
    }

    ChatHistorySelect(GuiCtrl, Item, Selected) {
        if (!Selected)
            return

        ; Deselect ContextBox to ensure mutual exclusion
        this.MyGui["ContextBox"].Modify(0, "-Select")

        messages := this.SessionManagerValue.GetCurrentSessionMessages()
        chatHistory := this.MyGui["ChatHistory"]
        
        ; Get the role of the selected item to check if it's a context row
        rowRole := chatHistory.GetText(Item, 1)
        
        if (rowRole == "📎") {
            ; This is a context row - find first user message and extract context
            firstUserMsg := ""
            for msg in messages {
                if (msg.Role == "user") {
                    firstUserMsg := msg
                    break
                }
            }
            
            if (firstUserMsg && firstUserMsg.AdditionalProperties.Has("hasContext") 
                && firstUserMsg.AdditionalProperties["hasContext"]
                && firstUserMsg.Contents.Length > 0 && (firstUserMsg.Contents[1] is TextContent)) {
                contextText := firstUserMsg.Contents[1].Text
                this.MyGui["ChatMessageActionButton"].Visible := true
                this.WebViewManagerValue.RenderMarkdown(contextText)
            }
        } else {
            ; Regular message - need to map ListView index to message index
            ; Count how many context rows exist before this item
            contextRowsBefore := 0
            Loop Item - 1 {
                if (chatHistory.GetText(A_Index, 1) == "📎")
                    contextRowsBefore++
            }
            
            messageIndex := Item - contextRowsBefore
            
            if (messageIndex > 0 && messageIndex <= messages.Length) {
                msg := messages[messageIndex]
                
                ; Check if this is the first user message with context
                isFirstUserMsg := false
                for i, m in messages {
                    if (m.Role == "user") {
                        isFirstUserMsg := (i == messageIndex)
                        break
                    }
                }
                
                ; Get message content
                messageContent := ""
                if (isFirstUserMsg && msg.AdditionalProperties.Has("hasContext") 
                    && msg.AdditionalProperties["hasContext"]) {
                    ; First user message with context - exclude first TextContent
                    text := ""
                    for i, part in msg.Contents {
                        if (i > 1 && part is TextContent) {
                            if (text != "")
                                text .= "`n"
                            text .= part.Text
                        }
                    }
                    
                    ; Check if has images
                    hasImage := false
                    for part in msg.Contents {
                        if (part is ImageContent) {
                            hasImage := true
                            break
                        }
                    }
                    
                    if (text == "" && !hasImage) {
                        text := "(empty message)"
                    }
                    
                    messageContent := hasImage ? text . " [Image]" : text
                } else {
                    ; Regular message - use normal display
                    messageContent := this.SessionManagerValue.GetMessageAsString(msg)
                }
                
                this.MyGui["ChatMessageActionButton"].Visible := true  ; Show the Copy button
                this.WebViewManagerValue.RenderMarkdown(messageContent)  ; Render the selected message in the WebView
            }
        }
    }

    CopySelectedMessage(*) {
        messages := this.SessionManagerValue.GetCurrentSessionMessages()
        chatHistory := this.MyGui["ChatHistory"]
        if (focused_row := chatHistory.GetNext()) {
            msg := messages[focused_row]
            messageText := msg.GetText()

            ClipText := StrReplace(messageText, "`r`n", "`n")
            ClipText := StrReplace(ClipText, "`r", "`n")
            ClipText := StrReplace(ClipText, "`n", "`r`n")
            A_Clipboard := ClipText
        }
    }

    DeleteSelectedMessage(*) {
        messages := this.SessionManagerValue.GetCurrentSessionMessages()
        chatHistory := this.MyGui["ChatHistory"]

        selectedIndices := []
        focused_row := 0

        ; Collect all selected rows, excluding system message and context rows
        while (focused_row := chatHistory.GetNext(focused_row)) {
            if (focused_row > 1) {  ; Don't include system message
                rowRole := chatHistory.GetText(focused_row, 1)
                if (rowRole != "📎") {  ; Don't include context rows
                    ; Map ListView index to message index
                    contextRowsBefore := 0
                    Loop focused_row - 1 {
                        if (chatHistory.GetText(A_Index, 1) == "📎")
                            contextRowsBefore++
                    }
                    messageIndex := focused_row - contextRowsBefore
                    selectedIndices.InsertAt(1, messageIndex)
                }
            }
        }

        ; Remove messages in reverse order to maintain correct indices
        for index in selectedIndices
            messages.RemoveAt(index)

        this.UpdateChatHistoryView()
        this.WebViewManagerValue.RenderMarkdown("")  ; Clear the response area
    }

    ClearChatHistory(*) {
        this.SessionManagerValue.ClearCurrentMessages()

        ; Update the system prompt content after clearing
        systemPrompt := this.AppSettingsValue.GetSystemPromptValue(
            this.SessionManagerValue.GetCurrentSessionLLMType(),
            this.SessionManagerValue.GetCurrentSessionSystemPrompt()
        )
        this.SessionManagerValue.UpdateSystemPromptContent(systemPrompt)

        this.UpdateChatHistoryView()  ; Update the chat history view
        this.WebViewManagerValue.RenderMarkdown("")  ; Clear the response area
    }
}
