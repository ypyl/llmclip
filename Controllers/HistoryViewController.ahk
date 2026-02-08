#Requires AutoHotkey 2.0

class HistoryViewController {
    controller := ""
    view := ""

    ; Commands
    getHistoryListItemsCommand := ""
    getMessagePresentationCommand := ""
    deleteMessageCommand := ""
    clearHistoryCommand := ""
    renderMarkdownCommand := ""
    copyToClipboardCommand := ""

    __New(controller, view, getHistoryListItemsCommand, getMessagePresentationCommand, deleteMessageCommand, clearHistoryCommand, renderMarkdownCommand, copyToClipboardCommand) {
        this.controller := controller
        this.view := view
        this.getHistoryListItemsCommand := getHistoryListItemsCommand
        this.getMessagePresentationCommand := getMessagePresentationCommand
        this.deleteMessageCommand := deleteMessageCommand
        this.clearHistoryCommand := clearHistoryCommand
        this.renderMarkdownCommand := renderMarkdownCommand
        this.copyToClipboardCommand := copyToClipboardCommand
    }

    UpdateChatHistoryView(*) {
        if (!this.controller || !this.controller.view) ; Check if initialized
            return

        items := this.getHistoryListItemsCommand.Execute()
        this.view.DeleteChatHistoryItems()
        
        for item in items {
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

        if (Item > 0) {
            presentationText := this.getMessagePresentationCommand.Execute(Item)
            
            this.view.SetChatMessageActionButtonVisible(true)  ; Show the Copy button
            this.renderMarkdownCommand.Execute(presentationText)  ; Render the selected message in the WebView
        }
    }

    CopySelectedMessage(*) {
        focused_row := this.view.GetChatHistoryFocus()
        if (focused_row) {
            messageText := this.getMessagePresentationCommand.Execute(focused_row, false)
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
