#Requires AutoHotkey 2.0

class HistoryViewController {
    SessionManagerValue := ""
    WebViewManagerValue := ""
    MyGui := ""

    __New(sessionManager, webViewManager) {
        this.SessionManagerValue := sessionManager
        this.WebViewManagerValue := webViewManager
    }

    SetGui(gui) {
        this.MyGui := gui
    }

    UpdateChatHistoryView(*) {
        if (!this.MyGui)
            return

        messages := this.SessionManagerValue.GetCurrentSessionMessagesAsStrings()
        chatHistory := this.MyGui["ChatHistory"]
        chatHistory.Delete()
        for msg in messages {
            duration := msg.HasOwnProp("duration") ? Round(msg.duration, 2) . "s" : ""
            tokens := msg.HasOwnProp("tokens") ? msg.tokens : ""
            chatHistory.Add(, msg.role, SubStr(msg.content, 1, 70) (StrLen(msg.content) > 70 ? "..." : ""), duration,
            tokens)
        }
        this.MyGui["ChatMessageActionButton"].Visible := false  ; Hide the Run Tool button
        if (chatHistory.GetCount() > 0) {
            chatHistory.Modify(chatHistory.GetCount(), "Vis")  ; Scroll to bottom
        }
    }

    ChatHistorySelect(*) {
        messages := this.SessionManagerValue.GetCurrentSessionMessages()
        chatHistory := this.MyGui["ChatHistory"]
        if (focused_row := chatHistory.GetNext()) {
            msg := messages[focused_row]
            this.MyGui["ChatMessageActionButton"].Visible := true  ; Show the Copy button
            this.WebViewManagerValue.RenderMarkdown(this.SessionManagerValue.GetMessageAsString(msg))  ; Render the selected message in the WebView
        }
    }

    CopySelectedMessage(*) {
        messages := this.SessionManagerValue.GetCurrentSessionMessages()
        chatHistory := this.MyGui["ChatHistory"]
        if (focused_row := chatHistory.GetNext()) {
            msg := messages[focused_row]
            messageText := msg.GetText()

            ClipText := StrReplace(messageText, "`r`n", "`n")
            ClipText := StrReplace(ClipText, "`r", "`n")
            ClipText := StrReplace(ClipText, "`n", "`r`n")
            A_Clipboard := ClipText
        }
    }

    DeleteSelectedMessage(*) {
        messages := this.SessionManagerValue.GetCurrentSessionMessages()
        chatHistory := this.MyGui["ChatHistory"]

        selectedIndices := []
        focused_row := 0

        ; Collect all selected rows
        while (focused_row := chatHistory.GetNext(focused_row))
            if (focused_row > 1)  ; Don't include system message
                selectedIndices.InsertAt(1, focused_row)

        ; Remove messages in reverse order to maintain correct indices
        for index in selectedIndices
            messages.RemoveAt(index)

        this.UpdateChatHistoryView()
        this.WebViewManagerValue.RenderMarkdown("")  ; Clear the response area
    }
}
