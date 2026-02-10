#Requires AutoHotkey 2.0

class ContextViewController {
    sessionManager := ""
    contextManager := ""
    webViewManager := ""
    view := ""
    contextPresentationService := ""
    deleteContextItemsCommand := ""
    prepareContextCommand := ""

    __New(view, sessionManager, contextManager, webViewManager, contextPresentationService, clearContextCommand, replaceLinkWithContentCommand, renderMarkdownCommand, deleteContextItemsCommand, prepareContextCommand) {
        this.view := view
        this.sessionManager := sessionManager
        this.contextManager := contextManager
        this.webViewManager := webViewManager
        this.contextPresentationService := contextPresentationService
        this.clearContextCommand := clearContextCommand
        this.replaceLinkWithContentCommand := replaceLinkWithContentCommand
        this.renderMarkdownCommand := renderMarkdownCommand
        this.deleteContextItemsCommand := deleteContextItemsCommand
        this.prepareContextCommand := prepareContextCommand
    }

    UpdateContextView(*) {
        if (!this.view) ; Check if initialized
            return

        ; Execute command to merge predefined context
        this.prepareContextCommand.Execute()

        context := this.sessionManager.GetCurrentSessionContext()

        ; Update UI
        this.view.DeleteContextBoxItems() ; Clear ListView

        ; Add items from context
        for item in context {
            listViewItem := this.contextPresentationService.GetListViewItem(item.Value)
            checkedOption := item.Checked ? "Check" : "-Check"
            row := this.view.AddContextBoxItem(listViewItem.label, checkedOption)
            
            if (!listViewItem.hasCheckbox) {
                this.view.RemoveContextBoxCheckbox(row)
            }
        }

        ; Modify column width to avoid horizontal scrollbar if possible or auto-size
        this.view.ModifyContextBoxCol(1, 350)
    }


    ContextBoxSelect(GuiCtrl, Item, Selected) {
        if (!Selected)
            return

        ; Deselect ChatHistory to ensure mutual exclusion
        this.view.ModifyChatHistory(0, "-Select")

        context := this.sessionManager.GetCurrentSessionContext()
        contextText := ""

        if (Item > 0 && Item <= context.Length) {
            targetItem := context[Item]
            if (this.contextManager.IsPdf(targetItem.Value)) {
                this.webViewManager.Navigate(targetItem.Value)
                return
            }

            ; Only load article if it is already cached or not a link
            ; For links that are not cached or replaced yet, we just show "URL: ..."
            ; The ContextManager now handles this based on IsHttpLink check.
            contextText := this.GetTextFromContextItem(targetItem)
        }

        this.renderMarkdownCommand.Execute(contextText)  ; Render the selected item(s) in the WebView
    }

    ContextBoxDoubleClick(GuiCtrl, Item) {
        if (!Item)
            return
            
        context := this.sessionManager.GetCurrentSessionContext()
        if (Item > 0 && Item <= context.Length) {
            targetItem := context[Item]
            if (this.contextManager.IsHttpLink(targetItem.Value)) {
                ; Execute command to replace link with content
                if (this.replaceLinkWithContentCommand.Execute(Item, targetItem.Value)) {
                    ; Refresh view to show updated content (now text)
                    this.UpdateContextView()
                    this.ContextBoxSelect(GuiCtrl, Item, true)
                }
            }
        }
    }

    ContextBoxItemCheck(Item, Checked) {
        this.sessionManager.SetContextItemChecked(Item, Checked)
    }

    DeleteSelected(*) {
        selectedIndices := []

        ; Get selected rows (highlighted, not necessarily checked)
        row := 0
        while (row := this.view.GetContextBoxNext(row)) {
            selectedIndices.InsertAt(1, row) ; Insert at beginning to keep reverse order
        }

        ; Execute command to remove selected items
        this.deleteContextItemsCommand.Execute(selectedIndices)

        ; Refresh the listview
        this.UpdateContextView()
    }

    ResetSelection(*) {
        this.view.ModifyContextBox(0, "-Select")  ; Deselect all
    }

    ClearAllContext(*) {
        this.clearContextCommand.Execute()
        this.UpdateContextView()
    }

    GetTextFromContextItem(item) {
        return this.contextManager.GetTextFromContextItem(item.Value)
    }
}
