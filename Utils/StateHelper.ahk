class StateHelper {
    static GetStatePath() => A_ScriptDir "\state.json"
    static GetConversationPath() => A_ScriptDir "\conversation.json"

    static Save(path, obj) => FileHelper.WriteText(path, JSON.Stringify(obj))

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
