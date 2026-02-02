#Requires AutoHotkey 2.0

class StartRecordingCommand {
    recordingService := ""

    __New(recordingService) {
        this.recordingService := recordingService
    }

    Execute() {
        return this.recordingService.StartRecording()
    }
}
