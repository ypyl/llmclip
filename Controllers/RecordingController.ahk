#Requires AutoHotkey 2.0

class RecordingController {
    topControlsView := ""
    mainView := ""
    trayView := ""
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

    SetViews(topControlsView, mainView) {
        this.topControlsView := topControlsView
        this.mainView := mainView
    }

    SetTrayView(trayView) {
        this.trayView := trayView
    }

    ToggleRecording(*) {
        if (!this.recordingService.isRecording) {
            this.startRecordingCommand.Execute()
            this.UpdateUiBasesOnRecordingStatus()
        } else if (this.mainView && !this.mainView.guiShown) {
            this.mainView.Show()
        } else {
            this.stopRecordingCommand.Execute()
            this.UpdateUiBasesOnRecordingStatus()
        }
    }

    UpdateUiBasesOnRecordingStatus(*) {
        if (this.mainView && this.mainView.guiShown) {
             this.topControlsView.UpdateRecordButton(this.recordingService.isRecording)
        }
        if (this.trayView) {
            this.trayView.UpdateStatus(this.recordingService.isRecording)
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
