class NavigateHistoryCommand {
    sessionManager := ""
    direction := ""
    
    __New(sessionManager, direction) {
        this.sessionManager := sessionManager
        this.direction := direction
    }
    
    Execute() {
        if (this.direction = "previous")
            return this.sessionManager.NavigateHistoryPrevious()
        else if (this.direction = "next")
            return this.sessionManager.NavigateHistoryNext()
        return false
    }
}
