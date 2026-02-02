class NotesController {
    view := ""
    copyToClipboardCommand := ""

    __New(copyToClipboardCommand) {
        this.copyToClipboardCommand := copyToClipboardCommand
        this.view := NotesView(this)
    }

    ShowNotes(content) {
        this.view.Show(content)
    }

    OnCopy(content) {
        this.copyToClipboardCommand.Execute(content)
        MsgBox("Copied to clipboard!", "Info", "T1")
    }

    OnClose() {
        this.view.Destroy()
    }
}
