class TopControlsView {
    sessionCombo := ""
    recordButton := ""
    resetButton := ""

    Create(gui, sessionNames, currentSessionIndex, isRecording, rootController, recordingController) {
        this.sessionCombo := gui.Add("DropDownList", "x10 y12 w70 vSessionSelect", sessionNames)
        this.sessionCombo.Value := currentSessionIndex
        this.sessionCombo.OnEvent("Change", ObjBindMethod(rootController, "SessionChanged"))

        recordButtonTitle := isRecording ? "Stop" : "Record"
        this.recordButton := gui.Add("Button", "x140 y10 w120 vRecordButton", recordButtonTitle)
        this.recordButton.OnEvent("Click", ObjBindMethod(recordingController, "ToggleRecording"))

        this.resetButton := gui.Add("Button", "x270 y10 w120", "Reset All")
        this.resetButton.OnEvent("Click", ObjBindMethod(rootController, "ResetAll"))
    }

    UpdateRecordButton(isRecording) {
        if (this.recordButton)
            this.recordButton.Text := isRecording ? "Stop" : "Record"
    }
    
    GetValue() => this.sessionCombo.Value
    SetValue(value) => this.sessionCombo.Value := value

    SetResetButtonEnabled(enabled) {
        if (this.resetButton)
            this.resetButton.Enabled := enabled
    }
}
