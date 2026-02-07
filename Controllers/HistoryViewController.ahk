#Requires AutoHotkey 2.0

class HistoryViewController {
    controller := ""
    sessionManager := ""
    configManager := ""

    ; Commands
    deleteMessageCommand := ""
    clearHistoryCommand := ""
    renderMarkdownCommand := ""
    copyToClipboardCommand := ""
    view := ""

    __New(controller, view, sessionManager, configManager, messagePresentationService, deleteMessageCommand, clearHistoryCommand, renderMarkdownCommand, copyToClipboardCommand) {
        this.controller := controller
        this.view := view
        this.sessionManager := sessionManager
        this.configManager := configManager
        this.messagePresentationService := messagePresentationService
        this.deleteMessageCommand := deleteMessageCommand
        this.clearHistoryCommand := clearHistoryCommand
        this.renderMarkdownCommand := renderMarkdownCommand
        this.copyToClipboardCommand := copyToClipboardCommand
    }

    UpdateChatHistoryView(*) {
        if (!this.controller || !this.controller.view) ; Check if initialized
            return

        allMessages := this.sessionManager.GetCurrentSessionMessages()
        this.view.DeleteChatHistoryItems()
        
        for i, msg in allMessages {
            item := this.messagePresentationService.GetListViewItem(msg)
            
            ; Add to ListView
            this.view.AddChatHistoryItem(item.roleEmoji, item.contentText, item.duration, item.tokens)
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
            
            ; Use presentation service
            presentationText := this.messagePresentationService.GetPresentationText(msg)
            
            this.view.SetChatMessageActionButtonVisible(true)  ; Show the Copy button
            this.renderMarkdownCommand.Execute(presentationText)  ; Render the selected message in the WebView
        }
    }

    CopySelectedMessage(*) {
        focused_row := this.view.GetChatHistoryFocus()
        if (focused_row) {
            messages := this.sessionManager.GetCurrentSessionMessages()
            msg := messages[focused_row]
           
            messageText := this.messagePresentationService.GetPresentationText(msg, false)
            this.copyToClipboardCommand.Execute(messageText)
        }
    }

    DeleteSelectedMessage(*) {
        selectedIndices := this.view.GetChatHistorySelectedIndices()
        this.deleteMessageCommand.Execute(selectedIndices)
        this.UpdateChatHistoryView()
        this.renderMarkdownCommand.Execute("")  ; Clear the response area
    }

    ClearChatHistory(*) {
        this.clearHistoryCommand.Execute()
        this.UpdateChatHistoryView()  ; Update the chat history view
        this.renderMarkdownCommand.Execute("")  ; Clear the response area
    }
}
