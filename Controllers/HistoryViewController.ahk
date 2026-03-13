#Requires AutoHotkey 2.0

class HistoryViewController {
    historyView := ""
    mainView := ""

    ; Commands
    getHistoryListItemsCommand := ""
    getMessagePresentationCommand := ""
    deleteMessageCommand := ""
    clearHistoryCommand := ""
    renderMarkdownCommand := ""
    copyToClipboardCommand := ""
    regenerateMessageCommand := ""
    navigateHistoryPreviousCommand := ""
    navigateHistoryNextCommand := ""
    getHistoryInfoCommand := ""
    setProcessingStateCommand := ""
    webViewManager := ""
    saveEditedMessageCommand := ""
    currentSelectedItem := 0

    __New(historyView, mainView, getHistoryListItemsCommand, getMessagePresentationCommand, deleteMessageCommand, clearHistoryCommand, renderMarkdownCommand, copyToClipboardCommand, regenerateMessageCommand, navigateHistoryPreviousCommand := "", navigateHistoryNextCommand := "", getHistoryInfoCommand := "", setProcessingStateCommand := "", webViewManager := "", saveEditedMessageCommand := "") {
        this.historyView := historyView
        this.mainView := mainView
        this.getHistoryListItemsCommand := getHistoryListItemsCommand
        this.getMessagePresentationCommand := getMessagePresentationCommand
        this.deleteMessageCommand := deleteMessageCommand
        this.clearHistoryCommand := clearHistoryCommand
        this.renderMarkdownCommand := renderMarkdownCommand
        this.copyToClipboardCommand := copyToClipboardCommand
        this.regenerateMessageCommand := regenerateMessageCommand
        this.navigateHistoryPreviousCommand := navigateHistoryPreviousCommand
        this.navigateHistoryNextCommand := navigateHistoryNextCommand
        this.getHistoryInfoCommand := getHistoryInfoCommand
        this.setProcessingStateCommand := setProcessingStateCommand
        this.webViewManager := webViewManager
        this.saveEditedMessageCommand := saveEditedMessageCommand
        
        if (this.webViewManager) {
            this.webViewManager.SetSaveEditCallback(ObjBindMethod(this, "OnMessageEdited"))
        }
    }

    UpdateChatHistoryView(focusedRow := 0) {
        if (!this.historyView)
            return

        items := this.getHistoryListItemsCommand.Execute()
        this.historyView.DeleteItems()

        for item in items {
            ; Add to ListView
            this.historyView.AddItem(item.roleEmoji, item.contentText, item.duration, item.tokens)
        }
        if (focusedRow) {
            this.historyView.Modify(focusedRow, "Select")
        }
        this.historyView.SetActionButtonVisible(false)  ; Hide the action button
        if (this.historyView.GetCount() > 0) {
            this.historyView.ScrollToBottom()  ; Scroll to bottom
        }
        
        if (this.getHistoryInfoCommand)
            this.historyView.SetHistoryInfo(this.getHistoryInfoCommand.Execute())
    }

    ChatHistorySelect(GuiCtrl, Item, Selected) {
        if (!Selected)
            return

        ; Deselect ContextBox to ensure mutual exclusion
        if (this.mainView)
            this.mainView.contextView.Modify(0, "-Select")

        if (Item > 0) {
            this.currentSelectedItem := Item
            presentationText := this.getMessagePresentationCommand.Execute(Item)

            this.historyView.SetActionButtonVisible(true)  ; Show the Copy button
            this.renderMarkdownCommand.Execute(presentationText)  ; Render the selected message in the WebView
        }
    }

    ChatHistoryDoubleClick(GuiCtrl, Item) {
        if (Item > 0 && this.regenerateMessageCommand) {
            messageText := this.regenerateMessageCommand.Execute(Item)
            if (messageText != "") {
                this.mainView.SetPromptValue(messageText)
                this.UpdateChatHistoryView()
            }
        }
    }

    CopySelectedMessage(*) {
        focused_row := this.historyView.GetNext()
        if (focused_row) {
            messageText := this.getMessagePresentationCommand.Execute(focused_row, false)
            this.copyToClipboardCommand.Execute(messageText)
        }
    }

    DeleteSelectedMessage(*) {
        selectedIndices := this.historyView.GetSelectedIndices()
        this.deleteMessageCommand.Execute(selectedIndices)
        this.UpdateChatHistoryView()
        this.renderMarkdownCommand.Execute("")  ; Clear the response area
    }

    ClearChatHistory(*) {
        this.clearHistoryCommand.Execute()
        this.UpdateChatHistoryView()  ; Update the chat history view
        this.renderMarkdownCommand.Execute("")  ; Clear the response area
        if (this.setProcessingStateCommand) {
            this.setProcessingStateCommand.Execute()
            this.mainView.SetAskButtonText("Ask LLM")
            this.mainView.SetAskButtonEnabled(true)
        }
    }

    NavigateHistoryPrevious(*) {
        if (this.navigateHistoryPreviousCommand && this.navigateHistoryPreviousCommand.Execute()) {
            this.UpdateChatHistoryView()
            this.renderMarkdownCommand.Execute("")  ; Clear the response area
        }
    }

    NavigateHistoryNext(*) {
        if (this.navigateHistoryNextCommand && this.navigateHistoryNextCommand.Execute()) {
            this.UpdateChatHistoryView()
            this.renderMarkdownCommand.Execute("")  ; Clear the response area
        }
    }

    OnMessageEdited(newText) {
        if (this.currentSelectedItem > 0 && this.saveEditedMessageCommand) {
            ; Save back to the session using the current selection index
            this.saveEditedMessageCommand.Execute(this.currentSelectedItem, newText)
            
            ; Determine row to focus (maintain current selection)
            rowToSelect := this.currentSelectedItem
            
            ; Update the list view and re-select the item
            this.UpdateChatHistoryView(rowToSelect)
            
            ; Since we just updated the text, re-render it into the WebView to make sure its correct 
            if (rowToSelect > 0) {
                 presentationText := this.getMessagePresentationCommand.Execute(rowToSelect)
                 this.renderMarkdownCommand.Execute(presentationText)
            }
        }
    }
}
