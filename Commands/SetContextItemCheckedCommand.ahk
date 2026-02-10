class SetContextItemCheckedCommand {
    sessionManager := ""

    __New(sessionManager) {
        this.sessionManager := sessionManager
    }

    Execute(itemIndex, checked) {
        this.sessionManager.SetContextItemChecked(itemIndex, checked)
    }
}
