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
    
    historyItems := []
    currentSelectedItem := 0  ; resolved message index

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

    /**
     * Resolves a ListView row number to the underlying item.
     */
    GetItemAt(listRow) {
        if (listRow < 1 || listRow > this.historyItems.Length)
            return ""
        return this.historyItems[listRow]
    }

    UpdateChatHistoryView(focusedRow := 0) {
        if (!this.historyView)
            return

        this.historyItems := this.getHistoryListItemsCommand.Execute()
        this.historyView.DeleteItems()

        for item in this.historyItems {
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
            itemData := this.GetItemAt(Item)
            if (!itemData)
                return

            ; Store the resolved message index for use by save/copy
            this.currentSelectedItem := itemData.messageIndex
            
            presentationText := this.getMessagePresentationCommand.Execute(itemData.messageIndex, itemData.isThinking, true, itemData.isContext)

            this.historyView.SetActionButtonVisible(true)  ; Show the Copy button
            this.renderMarkdownCommand.Execute(presentationText)  ; Render the selected message in the WebView
        }
    }

    ChatHistoryDoubleClick(GuiCtrl, Item) {
        if (Item > 0 && this.regenerateMessageCommand) {
            itemData := this.GetItemAt(Item)
            if (!itemData || itemData.isThinking || itemData.isContext)
                return  ; thinking/context rows cannot be regenerated
            
            messageText := this.regenerateMessageCommand.Execute(itemData.messageIndex)
            if (messageText != "") {
                this.mainView.SetPromptValue(messageText)
                this.UpdateChatHistoryView()
            }
        }
    }

    CopySelectedMessage(*) {
        listRow := this.historyView.GetNext()
        if (listRow) {
            itemData := this.GetItemAt(listRow)
            if (itemData) {
                messageText := this.getMessagePresentationCommand.Execute(itemData.messageIndex, itemData.isThinking, false, itemData.isContext)
                this.copyToClipboardCommand.Execute(messageText)
            }
        }
    }

    DeleteSelectedMessage(*) {
        selectedListRows := this.historyView.GetSelectedIndices()
        
        ; Resolve list-rows to unique message indices (deduplicate: thinking + message share same index)
        resolvedSet := Map()
        for row in selectedListRows {
            itemData := this.GetItemAt(row)
            if (itemData)
                resolvedSet[itemData.messageIndex] := true
        }

        resolvedIndices := []
        for idx in resolvedSet
            resolvedIndices.Push(idx)
        
        ; Sort descending so removals don't shift indices
        resolvedIndices := this._SortDescending(resolvedIndices)
        this.deleteMessageCommand.Execute(resolvedIndices)
        this.UpdateChatHistoryView()
        this.renderMarkdownCommand.Execute("")  ; Clear the response area
    }

    _SortDescending(arr) {
        ; Simple insertion sort descending
        sorted := arr.Clone()
        n := sorted.Length
        Loop n - 1 {
            i := A_Index + 1
            while (i > 1 && sorted[i] > sorted[i - 1]) {
                tmp := sorted[i]
                sorted[i] := sorted[i - 1]
                sorted[i - 1] := tmp
                i--
            }
        }
        return sorted
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
            ; Save back to the session using the resolved message index
            savedMsgIndex := this.currentSelectedItem
            this.saveEditedMessageCommand.Execute(savedMsgIndex, newText)

            ; Rebuild the list view (this also rebuilds historyItems)
            this.UpdateChatHistoryView()

            ; Find the list-row for the saved message (prefer non-thinking row)
            listRowToFocus := 0
            isThinking := false
            for i, item in this.historyItems {
                if (item.messageIndex == savedMsgIndex && !item.isThinking) {
                    listRowToFocus := i
                    isThinking := item.isThinking
                    break
                }
            }

            if (listRowToFocus > 0) {
                this.historyView.Modify(listRowToFocus, "Select")
                presentationText := this.getMessagePresentationCommand.Execute(savedMsgIndex, isThinking, true, false)
                this.renderMarkdownCommand.Execute(presentationText)
            }
        }
    }
}
