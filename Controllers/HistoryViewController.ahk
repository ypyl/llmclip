#Requires AutoHotkey 2.0

class HistoryViewController {
    controller := ""
    sessionManager := ""
    webViewManager := ""
    configManager := ""

    ; Commands
    deleteMessageCommand := ""
    view := ""

    __New(controller, view, sessionManager, webViewManager, configManager, messagePresentationService, deleteMessageCommand, clearHistoryCommand) {
        this.controller := controller
        this.view := view
        this.sessionManager := sessionManager
        this.webViewManager := webViewManager
        this.configManager := configManager
        this.messagePresentationService := messagePresentationService
        this.deleteMessageCommand := deleteMessageCommand
        this.clearHistoryCommand := clearHistoryCommand
    }

    UpdateChatHistoryView(*) {
        if (!this.controller || !this.controller.view) ; Check if initialized
            return

        allMessages := this.sessionManager.GetCurrentSessionMessages()
        this.view.DeleteChatHistoryItems()
        
        ; Identify first user message for presentation service
        firstUserIndex := 0
        for i, msg in allMessages {
            if (msg.Role == "user") {
                firstUserIndex := i
                break
            }
        }

        for i, msg in allMessages {
            roleEmoji := msg.Role == "system" ? "⚙️" :
                msg.Role == "user" ? "👤" :
                msg.Role == "assistant" ? "🤖" :
                msg.Role == "tool" ? "🛠️" : msg.Role

            duration := msg.AdditionalProperties.Has("duration") ? msg.AdditionalProperties["duration"] : ""
            tokens := msg.AdditionalProperties.Has("tokens") ? msg.AdditionalProperties["tokens"] : ""
            
            ; Get presentation text from service
            isFirstUserMsg := (i == firstUserIndex)
            presentationText := this.messagePresentationService.GetPresentationText(msg, isFirstUserMsg)
            
            ; Get content with truncation for ListView
            contentText := SubStr(presentationText, 1, 70) (StrLen(presentationText) > 70 ? "..." : "")
            
            ; Add to ListView
            row := this.view.AddChatHistoryItem(roleEmoji, contentText, duration, tokens)
            
            ; Check for batch indicators and modify the displayed content
            if (msg.AdditionalProperties.Has("isBatchMode") && msg.AdditionalProperties["isBatchMode"]) {
                this.view.ModifyChatHistory(row, "Col2", "🔄 [Batch] " . contentText)
            } else if (msg.AdditionalProperties.Has("isBatchResponse") && msg.AdditionalProperties["isBatchResponse"]) {
                itemLabel := msg.AdditionalProperties.Has("batchContextItem") ? msg.AdditionalProperties["batchContextItem"] : "Item"
                this.view.ModifyChatHistory(row, "Col2", "✅ [" . itemLabel . "] " . contentText)
            }
        }
        this.view.SetChatMessageActionButtonVisible(false)  ; Hide the action button
        if (this.view.GetChatHistoryCount() > 0) {
            this.view.ScrollChatHistoryToBottom()  ; Scroll to bottom
        }
    }

    ChatHistorySelect(GuiCtrl, Item, Selected) {
        if (!Selected)
            return

        ; Deselect ContextBox to ensure mutual exclusion
        this.view.ModifyContextBox(0, "-Select")

        messages := this.sessionManager.GetCurrentSessionMessages()
        
        if (Item > 0 && Item <= messages.Length) {
            msg := messages[Item]
            
            ; Identify first user message for presentation service
            isFirstUserMsg := false
            for i, m in messages {
                if (m.Role == "user") {
                    isFirstUserMsg := (i == Item)
                    break
                }
            }
            
            ; Use presentation service
            presentationText := this.messagePresentationService.GetPresentationText(msg, isFirstUserMsg)
            
            this.view.SetChatMessageActionButtonVisible(true)  ; Show the Copy button
            this.webViewManager.RenderMarkdown(presentationText)  ; Render the selected message in the WebView
        }
    }

    CopySelectedMessage(*) {
        focused_row := this.view.GetChatHistoryFocus()
        if (focused_row) {
            messages := this.sessionManager.GetCurrentSessionMessages()
            msg := messages[focused_row]
            
            ; Check if this is the first user message with context
            isFirstUserMsg := false
            for i, m in messages {
                if (m.Role == "user") {
                    isFirstUserMsg := (i == focused_row)
                    break
                }
            }
            
            ; Get text without context if first user message
            messageText := this.messagePresentationService.GetPresentationText(msg, isFirstUserMsg)

            ClipText := StrReplace(messageText, "`r`n", "`n")
            ClipText := StrReplace(ClipText, "`r", "`n")
            ClipText := StrReplace(ClipText, "`n", "`r`n")
            A_Clipboard := ClipText
        }
    }

    DeleteSelectedMessage(*) {
        selectedIndices := this.view.GetChatHistorySelectedIndices()
        this.deleteMessageCommand.Execute(selectedIndices)
        this.UpdateChatHistoryView()
        this.webViewManager.RenderMarkdown("")  ; Clear the response area
    }

    ClearChatHistory(*) {
        this.clearHistoryCommand.Execute()
        this.UpdateChatHistoryView()  ; Update the chat history view
        this.webViewManager.RenderMarkdown("")  ; Clear the response area
    }
}
