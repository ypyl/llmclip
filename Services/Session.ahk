#Include LLM\Types.ahk
#Include ContextItem.ahk
#Include History.ahk
#Include ProcessingState.ahk

class Session {
    histories := []
    currentHistoryIndex := 1
    context := []
    llmType := 1
    systemPromptIndex := 1
    processingState := ProcessingState.IDLE

    __New(defaultSystemPrompt, defaultModelIndex := 1) {
        this.histories := [History([ChatMessage("system", [TextContent(defaultSystemPrompt)])])]
        this.llmType := defaultModelIndex
    }

    GetCurrentHistory() => this.histories[this.currentHistoryIndex]

    GetCurrentMessages() => this.GetCurrentHistory().GetAll()

    AddMessages(messages) => this.GetCurrentHistory().Add(messages)

    CreateHistoryBranch(upToIndex) {
        newHistory := this.GetCurrentHistory().Branch(upToIndex)
        if (!newHistory)
            return false

        this.histories.Push(newHistory)
        this.currentHistoryIndex := this.histories.Length
        return true
    }

    NavigateHistoryPrevious() {
        if (this.currentHistoryIndex > 1) {
            this.currentHistoryIndex--
            return true
        }
        return false
    }

    NavigateHistoryNext() {
        if (this.currentHistoryIndex < this.histories.Length) {
            this.currentHistoryIndex++
            return true
        }
        return false
    }

    GetHistoryInfo() => this.currentHistoryIndex . "/" . this.histories.Length

    GetSystemMessage() {
        for msg in this.GetCurrentHistory().GetAll()
            if (msg.Role == "system")
                return msg
        return ""
    }

    ResetSesssion() {
        systemMsg := this.GetSystemMessage()
        this.histories := [History(systemMsg ? [systemMsg] : [])]
        this.currentHistoryIndex := 1
        this.context := []
        this.processingState := ProcessingState.IDLE
    }

    ResetHistory() {
        systemMsg := this.GetSystemMessage()
        this.histories := [History(systemMsg ? [systemMsg] : [])]
        this.currentHistoryIndex := 1
        this.processingState := ProcessingState.IDLE
    }

    UpdateSystemPrompt(systemPromptContent) {
        for msg in this.GetCurrentHistory().GetAll()
            if (msg.Role == "system") {
                msg.Contents := [TextContent(systemPromptContent)]
                return
            }
    }

    ToObject() {
        allHistories := []
        for hist in this.histories
            allHistories.Push(hist.ToObject())

        contextItems := []
        for item in this.context
            contextItems.Push(item.ToObject())

        return {
            histories: allHistories,
            historyIndex: this.currentHistoryIndex,
            context: contextItems,
            llmType: this.llmType,
            systemPrompt: this.systemPromptIndex,
            processingState: this.processingState
        }
    }

    static FromObject(obj) {
        hasHistories := obj.HasOwnProp("histories")
        hasMessages := obj.HasOwnProp("messages")

        if (!hasHistories && !hasMessages)
            throw Error("Invalid session data")

        newSession := Session("", 1)

        if (hasHistories) {
            newSession.histories := []
            for hist in obj.histories
                newSession.histories.Push(History.FromObject(hist))
            newSession.currentHistoryIndex := obj.historyIndex
        } else {
            newSession.histories := [History.FromObject(obj.messages)]
        }

        newSession.context := []
        for item in obj.context
            newSession.context.Push(ContextItem.FromObject(item))

        newSession.llmType := obj.llmType
        newSession.systemPromptIndex := obj.systemPrompt

        if (obj.HasOwnProp("processingState"))
            newSession.processingState := obj.processingState

        return newSession
    }
}
