#Requires AutoHotkey 2.0

class ContextViewController {
    controller := ""
    sessionManager := ""
    configManager := ""
    contextManager := ""
    webViewManager := ""
    clearContextCommand := ""
    MyGui := ""

    __New(controller, sessionManager, configManager, contextManager, webViewManager, clearContextCommand) {
        this.controller := controller
        this.sessionManager := sessionManager
        this.configManager := configManager
        this.contextManager := contextManager
        this.webViewManager := webViewManager
        this.clearContextCommand := clearContextCommand
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
            labels.Push(this.contextManager.GetLabelFromContextItem(item))
        }
        return labels
    }

    UpdateContextView(*) {
        if (!this.controller || !this.controller.view) ; Check if initialized
            return

        ; Update local references
        labels := this.GetLabelsForContextItems()

        ; Update UI
        this.controller.view.DeleteContextBoxItems() ; Clear ListView

        ; Add items and check them by default (except specific types)
        for label in labels {
            row := this.controller.view.AddContextBoxItem(label)
            ; Check if the underlying item is a PDF, if so, remove checkbox
            currentContext := this.sessionManager.GetCurrentSessionContext()
            if (A_Index <= currentContext.Length) {
                item := currentContext[A_Index]
                if (this.contextManager.IsPdf(item)) {
                     this.RemoveCheckbox(this.controller.view.GetContextBoxHwnd(), row)
                }
            }
        }

        ; Modify column width to avoid horizontal scrollbar if possible or auto-size
        this.controller.view.ModifyContextBoxCol(1, 350)
    }

    RemoveCheckbox(hwnd, row) {
        ; Remove state image (checkbox) by setting state image index to 0
        ; LVM_SETITEMSTATE = 0x102B
        ; LVITEM structure needed. 
        ; Mask coordinates might vary by architecture but simplified struct:
        ; UINT mask (0); int iItem (4); int iSubItem (8); UINT state (12); UINT stateMask (16)
        
        LVITEM := Buffer(60, 0) ; Sufficient size
        NumPut("UInt", 0x8, LVITEM, 0) ; mask = LVIF_STATE (0x0008)
        NumPut("Int", row - 1, LVITEM, 4) ; iItem (0-based)
        NumPut("Int", 0, LVITEM, 8) ; iSubItem
        NumPut("UInt", 0, LVITEM, 12) ; state (0 = no image)
        NumPut("UInt", 0xF000, LVITEM, 16) ; stateMask = LVIS_STATEIMAGEMASK (0xF000)

        SendMessage(0x102B, row - 1, LVITEM.Ptr, hwnd)
    }

    ContextBoxSelect(GuiCtrl, Item, Selected) {
        if (!Selected)
            return

        ; Deselect ChatHistory to ensure mutual exclusion
        this.controller.view.ModifyChatHistory(0, "-Select")

        context := this.sessionManager.GetCurrentSessionContext()
        contextText := ""

        if (Item > 0 && Item <= context.Length) {
            item := context[Item]
            if (this.contextManager.IsPdf(item)) {
                this.webViewManager.Navigate(item)
                return
            }
            contextText := this.GetTextFromContextItem(item)
        }

        this.webViewManager.RenderMarkdown(contextText)  ; Render the selected item(s) in the WebView
    }

    DeleteSelected(*) {
        context := this.sessionManager.GetCurrentSessionContext()
        selectedIndices := []

        ; Get selected rows (highlighted, not necessarily checked)
        row := 0
        while (row := this.controller.view.GetContextBoxNext(row)) {
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
        this.controller.view.ModifyContextBox(0, "-Select")  ; Deselect all
    }

    ClearAllContext(*) {
        this.clearContextCommand.Execute()
        this.UpdateContextView()
    }

    UncheckSentImages() {
        if (!this.controller || !this.controller.view)
            return
            
        context := this.sessionManager.GetCurrentSessionContext()

        loop this.controller.view.GetContextBoxCount() {
            ; Check if the item corresponds to an image
            if (A_Index <= context.Length) {
                item := context[A_Index]
                if (this.contextManager.IsImage(item) && this.controller.view.IsContextItemChecked(A_Index)) {
                    this.controller.view.ModifyContextBox(A_Index, "-Check")
                }
            }
        }
    }

    GetTextFromContextItem(item) {
        return this.contextManager.GetTextFromContextItem(item, (url) => this.webViewManager.LoadArticle(url))
    }

    GetCheckedImages() {
        images := []
        context := this.sessionManager.GetCurrentSessionContext()
        for index, item in context {
            if (this.controller.view.IsContextItemChecked(index) && this.contextManager.IsImage(item)) {
                images.Push(item)
            }
        }
        return images
    }

    GetAllCheckedContextItems() {
        checkedItems := []
        context := this.sessionManager.GetCurrentSessionContext()
        for index, item in context {
            if (this.controller.view.IsContextItemChecked(index)) {
                checkedItems.Push(item)
            }
        }
        return checkedItems
    }

    HasAnyCheckedItem() {
        context := this.sessionManager.GetCurrentSessionContext()
        loop context.Length {
            if (this.controller.view.IsContextItemChecked(A_Index)) {
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
