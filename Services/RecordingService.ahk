class RecordingService {
    isRecording := false
    
    StartRecording() {
        if (!this.isRecording) {
            this.isRecording := true
            return true
        }
        return false
    }

    StopRecording() {
        if (this.isRecording) {
            this.isRecording := false
            return true
        }
        return false
    }

    ToggleRecording() {
        if (this.isRecording) {
            return this.StopRecording()
        } else {
            return this.StartRecording()
        }
    }
}
