class HistoryView {
    chatHistory := ""
    deleteMessageButton := ""
    chatMessageButton := ""
    clearHistoryButton := ""

    Create(gui, historyViewController) {
        this.chatHistory := gui.Add("ListView", "vChatHistory x10 y220 w380 h150 NoSort", ["Role", "Text", "⏱️", "Tokens"])
        this.chatHistory.ModifyCol(1, 30)
        this.chatHistory.ModifyCol(2, 250)
        this.chatHistory.ModifyCol(3, 50)
        this.chatHistory.ModifyCol(4, 50)
        this.chatHistory.OnEvent("ItemSelect", ObjBindMethod(historyViewController, "ChatHistorySelect"))

        this.deleteMessageButton := gui.Add("Button", "x10 y375 w120", "Delete Selected")
        this.deleteMessageButton.OnEvent("Click", ObjBindMethod(historyViewController, "DeleteSelectedMessage"))

        this.chatMessageButton := gui.Add("Button", "vChatMessageActionButton x140 y375 w120 Hidden", "Copy")
        this.chatMessageButton.OnEvent("Click", ObjBindMethod(historyViewController, "CopySelectedMessage"))

        this.clearHistoryButton := gui.Add("Button", "x270 y375 w120", "Clear History")
        this.clearHistoryButton.OnEvent("Click", ObjBindMethod(historyViewController, "ClearChatHistory"))
    }

    DeleteItems() => this.chatHistory.Delete()
    AddItem(role, text, duration, tokens) => this.chatHistory.Add(, role, text, duration, tokens)
    Modify(row, options, text?) {
        if (IsSet(text)) {
            this.chatHistory.Modify(row, options, text)
        } else {
            this.chatHistory.Modify(row, options)
        }
    }
    GetCount() => this.chatHistory.GetCount()
    GetNext(row := 0) => this.chatHistory.GetNext(row)
    SetActionButtonVisible(visible) => this.chatMessageButton.Visible := visible
    ScrollToBottom() => this.chatHistory.Modify(this.chatHistory.GetCount(), "Vis")
    
    GetSelectedIndices() {
        selectedIndices := []
        row := 0
        while (row := this.chatHistory.GetNext(row)) {
            selectedIndices.InsertAt(1, row)
        }
        return selectedIndices
    }
}
