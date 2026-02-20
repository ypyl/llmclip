class GetHistoryInfoCommand {
    sessionManager := ""
    
    __New(sessionManager) {
        this.sessionManager := sessionManager
    }
    
    Execute() => this.sessionManager.GetHistoryInfo()
}
