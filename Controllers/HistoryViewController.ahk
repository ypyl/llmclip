#Requires AutoHotkey 2.0

class HistoryViewController {
    controller := ""
    sessionManager := ""
    webViewManager := ""
    MyGui := ""

    configManager := ""

    __New(controller, sessionManager, webViewManager, configManager) {
        this.controller := controller
        this.sessionManager := sessionManager
        this.webViewManager := webViewManager
        this.configManager := configManager
    }

    SetGui(gui) {
        this.MyGui := gui
    }

    UpdateChatHistoryView(*) {
        if (!this.controller || !this.controller.view) ; Check if initialized
            return

        messages := this.sessionManager.GetCurrentSessionMessagesAsStrings()
        this.controller.view.DeleteChatHistoryItems()
        for msg in messages {
            duration := msg.HasOwnProp("duration") ? msg.duration : ""
            tokens := msg.HasOwnProp("tokens") ? msg.tokens : ""
            
            ; Get content with truncation
            contentText := SubStr(msg.content, 1, 70) (StrLen(msg.content) > 70 ? "..." : "")
            
            ; Add to ListView
            row := this.controller.view.AddChatHistoryItem(msg.role, contentText, duration, tokens)
            
            ; Check for batch indicators and modify the displayed content
            if (msg.HasOwnProp("isBatchMode") && msg.isBatchMode) {
                this.controller.view.ModifyChatHistory(row, "Col2", "🔄 [Batch] " . contentText)
            } else if (msg.HasOwnProp("isBatchResponse") && msg.isBatchResponse) {
                itemLabel := msg.HasOwnProp("batchContextItem") ? msg.batchContextItem : "Item"
                this.controller.view.ModifyChatHistory(row, "Col2", "✅ [" . itemLabel . "] " . contentText)
            }
        }
        this.controller.view.SetChatMessageActionButtonVisible(false)  ; Hide the Run Tool button
        if (this.controller.view.GetChatHistoryCount() > 0) {
            this.controller.view.ScrollChatHistoryToBottom()  ; Scroll to bottom
        }
    }

    ChatHistorySelect(GuiCtrl, Item, Selected) {
        if (!Selected)
            return

        ; Deselect ContextBox to ensure mutual exclusion
        this.controller.view.ModifyContextBox(0, "-Select")

        messages := this.sessionManager.GetCurrentSessionMessages()
        
        if (Item > 0 && Item <= messages.Length) {
            msg := messages[Item]
            
            ; Check if this is the first user message with context
            isFirstUserMsg := false
            for i, m in messages {
                if (m.Role == "user") {
                    isFirstUserMsg := (i == Item)
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
                messageContent := this.sessionManager.GetMessageAsString(msg)
            }
            
            this.controller.view.SetChatMessageActionButtonVisible(true)  ; Show the Copy button
            this.webViewManager.RenderMarkdown(messageContent)  ; Render the selected message in the WebView
        }
    }

    CopySelectedMessage(*) {
        messages := this.sessionManager.GetCurrentSessionMessages()
        chatHistory := this.MyGui["ChatHistory"]
        if (focused_row := chatHistory.GetNext()) {
            msg := messages[focused_row]
            
            ; Check if this is the first user message with context
            isFirstUserMsg := false
            for i, m in messages {
                if (m.Role == "user") {
                    isFirstUserMsg := (i == focused_row)
                    break
                }
            }
            
            ; Get message content, excluding context if present
            messageText := ""
            if (isFirstUserMsg && msg.AdditionalProperties.Has("hasContext") 
                && msg.AdditionalProperties["hasContext"]) {
                ; First user message with context - exclude first TextContent
                for i, part in msg.Contents {
                    if (i > 1 && part is TextContent) {
                        if (messageText != "")
                            messageText .= "`n"
                        messageText .= part.Text
                    }
                }
            } else {
                ; Regular message - use normal GetText
                messageText := msg.GetText()
            }

            ClipText := StrReplace(messageText, "`r`n", "`n")
            ClipText := StrReplace(ClipText, "`r", "`n")
            ClipText := StrReplace(ClipText, "`n", "`r`n")
            A_Clipboard := ClipText
        }
    }

    DeleteSelectedMessage(*) {
        messages := this.sessionManager.GetCurrentSessionMessages()
        chatHistory := this.MyGui["ChatHistory"]

        selectedIndices := []
        focused_row := 0

        ; Collect all selected rows, excluding system message
        while (focused_row := chatHistory.GetNext(focused_row)) {
            if (focused_row > 1) {  ; Don't include system message
                selectedIndices.InsertAt(1, focused_row)
            }
        }

        ; Remove messages in reverse order to maintain correct indices
        for index in selectedIndices
            messages.RemoveAt(index)

        this.UpdateChatHistoryView()
        this.webViewManager.RenderMarkdown("")  ; Clear the response area
    }

    ClearChatHistory(*) {
        this.sessionManager.ClearCurrentMessages()

        ; Update the system prompt content after clearing
        systemPrompt := this.configManager.GetSystemPromptValue(
            this.sessionManager.GetCurrentSessionLLMType(),
            this.sessionManager.GetCurrentSessionSystemPrompt()
        )
        this.sessionManager.UpdateSystemPromptContent(systemPrompt)

        this.UpdateChatHistoryView()  ; Update the chat history view
        this.webViewManager.RenderMarkdown("")  ; Clear the response area
    }
}
