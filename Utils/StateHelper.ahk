class StateHelper {
    static GetStatePath() => A_ScriptDir "\state.json"
    static GetConversationPath() => A_ScriptDir "\conversation.json"

    static Save(path, obj) {
        jsonStr := JSON.Stringify(obj)
        if (FileExist(path))
            FileDelete(path)
        FileAppend(jsonStr, path, "UTF-8")
    }

    static Load(path) {
        if (!FileExist(path))
            return ""
        try {
            content := FileRead(path, "UTF-8")
            return JSON.Load(content)
        } catch {
            return ""
        }
    }

    static SaveState(stateObj) => StateHelper.Save(StateHelper.GetStatePath(), stateObj)
    static LoadState() => StateHelper.Load(StateHelper.GetStatePath())
    static SaveConversation(sessionObj) => StateHelper.Save(StateHelper.GetConversationPath(), sessionObj)
    static LoadConversation() => StateHelper.Load(StateHelper.GetConversationPath())
}
