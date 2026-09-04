class SaveStateOnExitCommand {
    sessionManager := ""
    configManager := ""

    __New(sessionManager, configManager) {
        this.sessionManager := sessionManager
        this.configManager := configManager
    }

    Execute() {
        stateObj := {
            toolOverrides: this.configManager.toolOverrides
        }
        StateHelper.SaveState(stateObj)
    }
}
