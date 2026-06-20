class ToggleRecordingCommand {
    recordingService := ""

    __New(recordingService) {
        this.recordingService := recordingService
    }

    Execute() {
        return this.recordingService.ToggleRecording()
    }
}
