#Requires AutoHotkey 2.0

class StopRecordingCommand {
    recordingService := ""

    __New(recordingService) {
        this.recordingService := recordingService
    }

    Execute() {
        return this.recordingService.StopRecording()
    }
}
