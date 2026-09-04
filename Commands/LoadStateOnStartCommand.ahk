class LoadStateOnStartCommand {
    sessionManager := ""
    configManager := ""

    __New(sessionManager, configManager) {
        this.sessionManager := sessionManager
        this.configManager := configManager
    }

    Execute() {
        state := StateHelper.LoadState()
        if (state == "")
            return false

        isMap := Type(state) = "Map"

        ; Restore tool overrides (per-session model/system prompt and the active
        ; session index now live in the all-sessions conversation file)
        hasToolOverrides := isMap ? state.Has("toolOverrides") : state.HasOwnProp("toolOverrides")
        if (hasToolOverrides) {
            overrides := isMap ? state["toolOverrides"] : state.toolOverrides
            if (Type(overrides) = "Map") {
                this.configManager.toolOverrides := overrides
            } else {
                ; Convert plain object to Map (from JSON deserialization)
                converted := Map()
                for modelKey, toolMap in overrides {
                    inner := Map()
                    for toolName, enabled in toolMap
                        inner[toolName] := enabled
                    converted[modelKey] := inner
                }
                this.configManager.toolOverrides := converted
            }
        }

        return true
    }
}
