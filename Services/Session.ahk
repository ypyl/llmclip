#Include LLM\Types.ahk
#Include ContextItem.ahk
#Include History.ahk
#Include ..\ProcessingState.ahk

class Session {
    histories := []
    currentHistoryIndex := 1
    context := []
    llmType := 1
    systemPromptIndex := 1
    processingState := ProcessingState.IDLE

    __New(defaultSystemPrompt, defaultLLMType := 1) {
        this.histories := [History([ChatMessage("system", [TextContent(defaultSystemPrompt)])])]
        this.llmType := defaultLLMType
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

    GetHistoryInfo() => "History " . this.currentHistoryIndex . "/" . this.histories.Length

    Reset(defaultSystemPrompt) {
        this.histories := [History([ChatMessage("system", [TextContent(defaultSystemPrompt)])])]
        this.currentHistoryIndex := 1
        this.context := []
        this.processingState := ProcessingState.IDLE
    }

    UpdateSystemPrompt(systemPromptContent) {
        currentHistory := this.GetCurrentHistory()
        if (currentHistory.Length() > 0 && currentHistory.Get(1).Role == "system") {
            currentHistory.Get(1).Contents := [TextContent(systemPromptContent)]
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

    static FromObject(obj, convertMapFunc) {
        isMap := Type(obj) = "Map"
        
        hasHistories := isMap ? obj.Has("histories") : obj.HasOwnProp("histories")
        hasMessages := isMap ? obj.Has("messages") : obj.HasOwnProp("messages")
        
        if (!hasHistories && !hasMessages)
            throw Error("Invalid session data")

        newSession := Session("", 1)
        
        if (hasHistories) {
            histories := isMap ? obj["histories"] : obj.histories
            newSession.histories := []
            for hist in histories
                newSession.histories.Push(History.FromObject(hist, convertMapFunc))
            newSession.currentHistoryIndex := isMap ? obj["historyIndex"] : obj.historyIndex
        } else {
            messages := isMap ? obj["messages"] : obj.messages
            newSession.histories := [History.FromObject(messages, convertMapFunc)]
        }

        context := isMap ? obj["context"] : obj.context
        newSession.context := []
        for item in context
            newSession.context.Push(ContextItem.FromObject(item))

        newSession.llmType := isMap ? obj["llmType"] : obj.llmType
        newSession.systemPromptIndex := isMap ? obj["systemPrompt"] : obj.systemPrompt
        
        hasProcessingState := isMap ? obj.Has("processingState") : obj.HasOwnProp("processingState")
        if (hasProcessingState)
            newSession.processingState := isMap ? obj["processingState"] : obj.processingState

        return newSession
    }
}
