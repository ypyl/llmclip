class NotesView {
    gui := ""
    controller := ""
    notesEdit := ""
    
    __New(controller) {
        this.controller := controller
    }

    Show(content) {
        this.gui := Gui()
        this.gui.Title := "Extracted Notes"
        this.gui.SetFont("s10", "Segoe UI")

        this.gui.Add("Text", "x10 y10 w580 h20", "Here are the extracted notes from your conversation:")

        this.notesEdit := this.gui.Add("Edit", "x10 y40 w580 h350 Multi ReadOnly vNotesEdit", content)

        copyBtn := this.gui.Add("Button", "x10 y400 w150 h30", "Copy to Clipboard")
        copyBtn.OnEvent("Click", (*) => this.controller.OnCopy(content))

        closeBtn := this.gui.Add("Button", "x490 y400 w100 h30", "Close")
        closeBtn.OnEvent("Click", (*) => this.controller.OnClose())

        this.gui.Show("w600 h450")
    }

    Destroy() {
        if (this.gui) {
            this.gui.Destroy()
            this.gui := ""
        }
    }
}
