#Requires AutoHotkey 2.0

class ContextViewController {
    controller := ""
    sessionManager := ""
    configManager := ""
    contextManager := ""
    webViewManager := ""
    view := ""
    MyGui := ""
    contextPresentationService := ""
    clearContextCommand := ""
    replaceLinkWithContentCommand := ""

    __New(controller, view, sessionManager, configManager, contextManager, webViewManager, contextPresentationService, clearContextCommand, replaceLinkWithContentCommand) {
        this.controller := controller
        this.view := view
        this.sessionManager := sessionManager
        this.configManager := configManager
        this.contextManager := contextManager
        this.webViewManager := webViewManager
        this.contextPresentationService := contextPresentationService
        this.clearContextCommand := clearContextCommand
        this.replaceLinkWithContentCommand := replaceLinkWithContentCommand
    }

    SetGui(gui) {
        this.MyGui := gui
    }

    GetLabelsForContextItems() {
        context := this.sessionManager.GetCurrentSessionContext()
        predefinedContext := this.configManager.GetContext(this.sessionManager.GetCurrentSessionLLMType(),
        this.sessionManager.GetCurrentSessionSystemPrompt())
        labels := []
        for item in predefinedContext {
            if (!this.HasVal(context, item)) {
                context.Push(item)
            }
        }
        this.sessionManager.SetCurrentSessionContext(context)
        for item in context {
            labels.Push(this.contextPresentationService.GetLabelFromContextItem(item))
        }
        return labels
    }

    UpdateContextView(*) {
        if (!this.controller || !this.controller.view) ; Check if initialized
            return

        ; Update local references
        labels := this.GetLabelsForContextItems()

        ; Update UI
        this.view.DeleteContextBoxItems() ; Clear ListView

        ; Add items and check them by default (except specific types)
        for label in labels {
            row := this.view.AddContextBoxItem(label)
            ; Check if the underlying item is a PDF, if so, remove checkbox
            currentContext := this.sessionManager.GetCurrentSessionContext()
            if (A_Index <= currentContext.Length) {
                item := currentContext[A_Index]
                if (this.contextManager.IsPdf(item)) {
                     this.view.RemoveContextBoxCheckbox(row)
                }
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
            contextItem := context[Item]
            if (this.contextManager.IsPdf(contextItem)) {
                this.webViewManager.Navigate(contextItem)
                return
            }

            ; Only load article if it is already cached or not a link
            ; For links that are not cached or replaced yet, we just show "URL: ..."
            ; The ContextManager now handles this based on IsHttpLink check.
            contextText := this.GetTextFromContextItem(contextItem)
        }

        this.webViewManager.RenderMarkdown(contextText)  ; Render the selected item(s) in the WebView
    }

    ContextBoxDoubleClick(GuiCtrl, Item) {
        if (!Item)
            return
            
        context := this.sessionManager.GetCurrentSessionContext()
        if (Item > 0 && Item <= context.Length) {
            contextItem := context[Item]
            if (this.contextManager.IsHttpLink(contextItem)) {
                ; Execute command to replace link with content
                if (this.replaceLinkWithContentCommand.Execute(Item, contextItem)) {
                    ; Refresh view to show updated content (now text)
                    this.UpdateContextView()
                    this.ContextBoxSelect(GuiCtrl, Item, true)
                }
            }
        }
    }

    DeleteSelected(*) {
        context := this.sessionManager.GetCurrentSessionContext()
        selectedIndices := []

        ; Get selected rows (highlighted, not necessarily checked)
        row := 0
        while (row := this.view.GetContextBoxNext(row)) {
            selectedIndices.InsertAt(1, row) ; Insert at beginning to keep reverse order
        }

        ; Remove selected items
        for index in selectedIndices {
            context.RemoveAt(index)
        }

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

    UncheckSentImages() {
        if (!this.controller || !this.controller.view)
            return
            
        context := this.sessionManager.GetCurrentSessionContext()

        loop this.view.GetContextBoxCount() {
            ; Check if the item corresponds to an image
            if (A_Index <= context.Length) {
                item := context[A_Index]
                if (this.contextManager.IsImage(item) && this.view.IsContextItemChecked(A_Index)) {
                    this.view.ModifyContextBox(A_Index, "-Check")
                }
            }
        }
    }

    GetTextFromContextItem(item) {
        return this.contextManager.GetTextFromContextItem(item)
    }

    GetCheckedImages() {
        images := []
        context := this.sessionManager.GetCurrentSessionContext()
        for index, item in context {
            if (this.view.IsContextItemChecked(index) && this.contextManager.IsImage(item)) {
                images.Push(item)
            }
        }
        return images
    }

    GetAllCheckedContextItems() {
        checkedItems := []
        context := this.sessionManager.GetCurrentSessionContext()
        for index, item in context {
            if (this.view.IsContextItemChecked(index)) {
                checkedItems.Push(item)
            }
        }
        return checkedItems
    }

    HasAnyCheckedItem() {
        context := this.sessionManager.GetCurrentSessionContext()
        loop context.Length {
            if (this.view.IsContextItemChecked(A_Index)) {
                return true
            }
        }
        return false
    }

    HasVal(haystack, needle) {
        for index, value in haystack {
            if (value = needle)
                return true
        }
        return false
    }
}
