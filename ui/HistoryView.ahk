class HistoryView {
    chatHistory := ""
    deleteMessageButton := ""
    chatMessageButton := ""
    clearHistoryButton := ""
    historyPrevButton := ""
    historyNextButton := ""
    historyInfoText := ""

    Create(gui, historyViewController) {
        this.chatHistory := gui.Add("ListView", "vChatHistory x10 y220 w380 h150 NoSort", ["Role", "Text", "⏱️", "Tokens"])
        this.chatHistory.ModifyCol(1, 30)
        this.chatHistory.ModifyCol(2, 250)
        this.chatHistory.ModifyCol(3, 50)
        this.chatHistory.ModifyCol(4, 50)
        this.chatHistory.OnEvent("ItemSelect", ObjBindMethod(historyViewController, "ChatHistorySelect"))
        this.chatHistory.OnEvent("DoubleClick", ObjBindMethod(historyViewController, "ChatHistoryDoubleClick"))

        this.deleteMessageButton := gui.Add("Button", "x10 y375 w30", "X")
        this.deleteMessageButton.OnEvent("Click", ObjBindMethod(historyViewController, "DeleteSelectedMessage"))

        this.chatMessageButton := gui.Add("Button", "vChatMessageActionButton x45 y375 w60 Hidden", "Copy")
        this.chatMessageButton.OnEvent("Click", ObjBindMethod(historyViewController, "CopySelectedMessage"))

        this.clearHistoryButton := gui.Add("Button", "x110 y375 w60", "Clear")
        this.clearHistoryButton.OnEvent("Click", ObjBindMethod(historyViewController, "ClearChatHistory"))

        this.historyPrevButton := gui.Add("Button", "x175 y375 w30", "<")
        this.historyPrevButton.OnEvent("Click", ObjBindMethod(historyViewController, "NavigateHistoryPrevious"))

        this.historyNextButton := gui.Add("Button", "x210 y375 w30", ">")
        this.historyNextButton.OnEvent("Click", ObjBindMethod(historyViewController, "NavigateHistoryNext"))

        this.historyInfoText := gui.Add("Text", "x245 y380 w145 Center", "History 1/1")
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
    SetHistoryInfo(text) => this.historyInfoText.Value := text
    
    GetSelectedIndices() {
        selectedIndices := []
        row := 0
        while (row := this.chatHistory.GetNext(row)) {
            selectedIndices.InsertAt(1, row)
        }
        return selectedIndices
    }
}
