class TopControlsView {
    recordButton := ""
    resetButton := ""

    Create(gui, isRecording, recordingController, rootController) {
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
    

    SetResetButtonEnabled(enabled) {
        if (this.resetButton)
            this.resetButton.Enabled := enabled
    }
}
