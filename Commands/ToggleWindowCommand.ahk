#Requires AutoHotkey 2.0

class ToggleWindowCommand {
    recordingService := ""
    view := ""
    startRecordingCommand := ""
    stopRecordingCommand := ""

    __New(recordingService, view, startRecordingCommand, stopRecordingCommand) {
        this.recordingService := recordingService
        this.view := view
        this.startRecordingCommand := startRecordingCommand
        this.stopRecordingCommand := stopRecordingCommand
    }

    Execute() {
        if (!this.recordingService.isRecording) {
            this.startRecordingCommand.Execute()
            this.UpdateUi()
        } else if (!this.view.guiShown) {
            this.view.Show()
        } else {
            this.stopRecordingCommand.Execute()
            this.UpdateUi()
        }
    }

    UpdateUi() {
        if (this.view.guiShown) {
            this.view.UpdateRecordButton(this.recordingService.isRecording)
        }
    }
}
