class StateHelper {
    static GetStatePath() => A_ScriptDir "\state.json"
    static GetConversationPath() => A_ScriptDir "\conversation.json"

    static Save(path, obj) {
        tmpPath := path . ".tmp"
        try {
            FileHelper.WriteText(tmpPath, JSON.Stringify(obj))
            ; Replace atomically — a failed/interrupted save leaves the previous file intact
            FileMove(tmpPath, path, 1)
        } catch as e {
            try FileDelete(tmpPath)
            throw e
        }
    }

    static Load(path) {
        if (!FileExist(path))
            return ""
        try {
            return JSON.Load(FileHelper.ReadText(path))
        } catch {
            return ""
        }
    }

    static SaveState(stateObj) => StateHelper.Save(StateHelper.GetStatePath(), stateObj)
    static LoadState() => StateHelper.Load(StateHelper.GetStatePath())
    static SaveConversation(sessionObj) => StateHelper.Save(StateHelper.GetConversationPath(), sessionObj)
    static LoadConversation() => StateHelper.Load(StateHelper.GetConversationPath())
}
