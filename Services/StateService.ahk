class StateService {
    GetStatePath() => A_ScriptDir "\state.json"
    GetConversationPath() => A_ScriptDir "\conversation.json"

    SaveState(stateObj) {
        jsonStr := JSON.Stringify(stateObj)
        path := this.GetStatePath()
        if (FileExist(path))
            FileDelete(path)
        FileAppend(jsonStr, path, "UTF-8")
    }

    LoadState() {
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

    SaveConversation(sessionObj) {
        jsonStr := JSON.Stringify(sessionObj)
        path := this.GetConversationPath()
        if (FileExist(path))
            FileDelete(path)
        FileAppend(jsonStr, path, "UTF-8")
    }

    LoadConversation() {
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
