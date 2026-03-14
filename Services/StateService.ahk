class StateService {
    static GetStatePath() => A_ScriptDir "\state.json"
    static GetConversationPath() => A_ScriptDir "\conversation.json"

    static SaveState(stateObj) {
        jsonStr := JSON.Stringify(stateObj)
        path := this.GetStatePath()
        if (FileExist(path))
            FileDelete(path)
        FileAppend(jsonStr, path, "UTF-8")
    }

    static LoadState() {
        path := this.GetStatePath()
        if (!FileExist(path))
            return ""
        try {
            content := FileRead(path, "UTF-8")
            return JSON.Load(content)
        } catch {
            return ""
        }
    }

    static SaveConversation(sessionObj) {
        jsonStr := JSON.Stringify(sessionObj)
        path := this.GetConversationPath()
        if (FileExist(path))
            FileDelete(path)
        FileAppend(jsonStr, path, "UTF-8")
    }

    static LoadConversation() {
        path := this.GetConversationPath()
        if (!FileExist(path))
            return ""
        try {
            content := FileRead(path, "UTF-8")
            return JSON.Load(content)
        } catch {
            return ""
        }
    }
}
