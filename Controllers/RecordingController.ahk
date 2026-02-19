#Requires AutoHotkey 2.0

class RecordingController {
    view := ""
    recordingService := ""
    startRecordingCommand := ""
    stopRecordingCommand := ""
    toggleRecordingCommand := ""

    __New(recordingService, startRecordingCommand, stopRecordingCommand, toggleRecordingCommand) {
        this.recordingService := recordingService
        this.startRecordingCommand := startRecordingCommand
        this.stopRecordingCommand := stopRecordingCommand
        this.toggleRecordingCommand := toggleRecordingCommand
    }

    SetView(view) {
        this.view := view
    }

    ToggleRecording(*) {
        if (!this.recordingService.isRecording) {
            this.startRecordingCommand.Execute()
            this.UpdateUiBasesOnRecordingStatus()
        } else if (this.view && !this.view.guiShown) {
            this.view.Show()
        } else {
            this.stopRecordingCommand.Execute()
            this.UpdateUiBasesOnRecordingStatus()
        }
    }

    UpdateUiBasesOnRecordingStatus(*) {
        if (this.view && this.view.guiShown) {
             this.view.UpdateRecordButton(this.recordingService.isRecording)
        }
    }

    OnStartRecording() {
        this.startRecordingCommand.Execute()
        this.UpdateUiBasesOnRecordingStatus()
    }

    OnStopRecording() {
        this.stopRecordingCommand.Execute()
        this.UpdateUiBasesOnRecordingStatus()
    }

    OnToggleRecording() {
        this.toggleRecordingCommand.Execute()
        this.UpdateUiBasesOnRecordingStatus()
    }
}
