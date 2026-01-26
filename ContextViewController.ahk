#Requires AutoHotkey 2.0

class ContextViewController {
    SessionManagerValue := ""
    AppSettingsValue := ""
    ContextManagerValue := ""
    WebViewManagerValue := ""
    MyGui := ""

    __New(sessionManager, appSettings, contextManager, webViewManager) {
        this.SessionManagerValue := sessionManager
        this.AppSettingsValue := appSettings
        this.ContextManagerValue := contextManager
        this.WebViewManagerValue := webViewManager
    }

    SetGui(gui) {
        this.MyGui := gui
    }

    GetLabelsForContextItems() {
        context := this.SessionManagerValue.GetCurrentSessionContext()
        predefinedContext := this.AppSettingsValue.GetContext(this.SessionManagerValue.GetCurrentSessionLLMType(),
        this.SessionManagerValue.GetCurrentSessionSystemPrompt())
        labels := []
        for item in predefinedContext {
            if (!this.HasVal(context, item)) {
                context.Push(item)
            }
        }
        this.SessionManagerValue.SetCurrentSessionContext(context)
        for item in context {
            labels.Push(this.ContextManagerValue.GetLabelFromContextItem(item))
        }
        return labels
    }

    UpdateContextView(*) {
        if (!this.MyGui)
            return

        ; Update local references
        labels := this.GetLabelsForContextItems()

        ; Update UI
        contextBox := this.MyGui["ContextBox"]
        contextBox.Delete() ; Clear ListView

        ; Add items and check them by default (except specific types)
        for label in labels {
            row := contextBox.Add("Check", label)
            ; Check if the underlying item is a PDF, if so, remove checkbox
            currentContext := this.SessionManagerValue.GetCurrentSessionContext()
            if (A_Index <= currentContext.Length) {
                item := currentContext[A_Index]
                if (this.ContextManagerValue.IsPdf(item)) {
                     this.RemoveCheckbox(contextBox, row)
                }
            }
        }

        ; Modify column width to avoid horizontal scrollbar if possible or auto-size
        contextBox.ModifyCol(1, 350)
    }

    RemoveCheckbox(contextBox, row) {
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

        SendMessage(0x102B, row - 1, LVITEM.Ptr, contextBox.Hwnd)
    }

    ContextBoxSelect(GuiCtrl, Item, Selected) {
        if (!Selected)
            return

        ; Deselect ChatHistory to ensure mutual exclusion
        this.MyGui["ChatHistory"].Modify(0, "-Select")

        context := this.SessionManagerValue.GetCurrentSessionContext()
        contextText := ""

        if (Item > 0 && Item <= context.Length) {
            item := context[Item]
            if (this.ContextManagerValue.IsPdf(item)) {
                this.WebViewManagerValue.Navigate(item)
                return
            }
            contextText := this.GetTextFromContextItem(item)
        }

        this.WebViewManagerValue.RenderMarkdown(contextText)  ; Render the selected item(s) in the WebView
    }

    DeleteSelected(*) {
        context := this.SessionManagerValue.GetCurrentSessionContext()
        contextBox := this.MyGui["ContextBox"]
        selectedIndices := []

        ; Get selected rows (highlighted, not necessarily checked)
        row := 0
        while (row := contextBox.GetNext(row)) {
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
        contextBox := this.MyGui["ContextBox"]
        contextBox.Modify(0, "-Select")  ; Deselect all
    }

    ClearAllContext(*) {
        this.SessionManagerValue.SetCurrentSessionContext([])
        this.UpdateContextView()
    }

    UncheckSentImages() {
        if (!this.MyGui)
            return
            
        contextBox := this.MyGui["ContextBox"]
        context := this.SessionManagerValue.GetCurrentSessionContext()

        loop contextBox.GetCount() {
            ; Check if the item corresponds to an image
            if (A_Index <= context.Length) {
                item := context[A_Index]
                if (this.ContextManagerValue.IsImage(item)) {
                    contextBox.Modify(A_Index, "-Check")
                }
            }
        }
    }

    GetTextFromContextItem(item) {
        return this.ContextManagerValue.GetTextFromContextItem(item, (url) => this.WebViewManagerValue.LoadArticle(url))
    }

    BuildAdditionalContextMessage(context, contextBoxValue) {
        if (context.Length = 0)
            return ""

        contextText := ""
        selectedIndices := []

        ; Get selected indices
        if (contextBoxValue is Array) {
            selectedIndices := contextBoxValue
        } else if (contextBoxValue) {
            selectedIndices := [contextBoxValue]
        }

        ; Build context excluding selected items AND unchecked items AND images AND PDFs
        for index, item in context {
            if (this.IsItemChecked(index) && !this.HasVal(selectedIndices, index) && !this.ContextManagerValue.IsImage(item) && !this.ContextManagerValue.IsPdf(item)) {
                contextText .= this.GetTextFromContextItem(item)
            }
        }

        messageContent := ""

        ; Only add general context if there is any non-selected content
        if (contextText != "") {
            messageContent .= "Use information from the following context. If the information is not relevant, do not use it. If you need more information, ask.`n`n<CONTEXT>`n" contextText "`n<CONTEXT>"
        }

        ; Add selected items as special focus points (excluding images)
        if (selectedIndices.Length > 0) {
            messageContent .= "`n`n<SELECTED_CONTEXT>`n"
            for index in selectedIndices {
                if (this.IsItemChecked(index) && !this.ContextManagerValue.IsImage(context[index])) {
                    messageContent .= this.GetTextFromContextItem(context[index])
                }
            }
            messageContent .= "`n<SELECTED_CONTEXT>"
        }

        return messageContent
    }

    ; Helper to check if an item is checked in the ListView
    IsItemChecked(index) {
        if (!this.MyGui)
            return true ; Default to true if GUI not available

        try {
            contextBox := this.MyGui["ContextBox"]
            Result := SendMessage(0x102C, index-1, 0xF000, contextBox.Hwnd)
            State := (Result >> 12) - 1
            return State == 1
        } catch {
            return true ; Fallback
        }
    }

    GetCheckedImages() {
        images := []
        context := this.SessionManagerValue.GetCurrentSessionContext()
        for index, item in context {
            if (this.IsItemChecked(index) && this.ContextManagerValue.IsImage(item)) {
                images.Push(item)
            }
        }
        return images
    }

    GetAllCheckedContextItems() {
        checkedItems := []
        context := this.SessionManagerValue.GetCurrentSessionContext()
        for index, item in context {
            if (this.IsItemChecked(index)) {
                checkedItems.Push(item)
            }
        }
        return checkedItems
    }

    HasAnyCheckedItem() {
        context := this.SessionManagerValue.GetCurrentSessionContext()
        loop context.Length {
            if (this.IsItemChecked(A_Index)) {
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
