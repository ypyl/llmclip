#Include LLM\Types.ahk
#Include ContextItem.ahk
#Include ProcessingState.ahk

class Session {
    histories := []
    currentHistoryIndex := 1
    context := []
    llmType := 1
    systemPromptIndex := 1
    processingState := ProcessingState.IDLE

    __New(defaultSystemPrompt, defaultModelIndex := 1) {
        this.histories := [[ChatMessage("system", [TextContent(defaultSystemPrompt)])]]
        this.llmType := defaultModelIndex
    }

    GetCurrentHistory() => this.histories[this.currentHistoryIndex]

    GetCurrentMessages() => this.GetCurrentHistory()

    CreateHistoryBranch(upToIndex) {
        messages := this.GetCurrentHistory()
        if (upToIndex <= 0 || upToIndex >= messages.Length)
            return false

        newHistory := []
        Loop upToIndex
            newHistory.Push(messages[A_Index])

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
        for msg in this.GetCurrentHistory()
            if (msg.Role == "system")
                return msg
        return ""
    }

    ResetSesssion() {
        systemMsg := this.GetSystemMessage()
        this.histories := [systemMsg ? [systemMsg] : []]
        this.currentHistoryIndex := 1
        this.context := []
        this.processingState := ProcessingState.IDLE
    }

    ResetHistory() {
        systemMsg := this.GetSystemMessage()
        this.histories := [systemMsg ? [systemMsg] : []]
        this.currentHistoryIndex := 1
        this.processingState := ProcessingState.IDLE
    }

    UpdateSystemPrompt(systemPromptContent) {
        for msg in this.GetCurrentHistory()
            if (msg.Role == "system") {
                msg.Contents := [TextContent(systemPromptContent)]
                return
            }
    }

    ToObject() {
        allHistories := []
        for hist in this.histories {
            messages := []
            for msg in hist
                messages.Push(msg.ToObject(true))
            allHistories.Push(messages)
        }

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
            for hist in obj.histories {
                messages := []
                for msg in hist
                    messages.Push(ChatMessage.FromObject(msg))
                newSession.histories.Push(messages)
            }
            newSession.currentHistoryIndex := obj.historyIndex
        } else {
            messages := []
            for msg in obj.messages
                messages.Push(ChatMessage.FromObject(msg))
            newSession.histories := [messages]
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
