class NotesController {
    view := ""

    __New() {
        this.view := NotesView(this)
    }

    ShowNotes(content) {
        this.view.Show(content)
    }

    OnCopy(content) {
        A_Clipboard := content
        MsgBox("Copied to clipboard!", "Info", "T1")
    }

    OnClose() {
        this.view.Destroy()
    }
}
