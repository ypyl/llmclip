#Include LLM\Types.ahk
#Include ContextItem.ahk
#Include Session.ahk

class SessionManager {
    currentSessionIndex := 1
    MAX_SESSIONS := 5
    sessionNames := ["Session 1", "Session 2", "Session 3", "Session 4", "Session 5"]
    sessions := []

    defaultSystemPrompt := "You are a helpful assistant. Be concise and direct in your responses."
    defaultLLMType := 1
    contextManager := ""
    answerSize := "Default"
    batchModeEnabled := false

    __New(defaultLLMType := 1, defaultSystemPrompt := "", contextManager := "") {
        this.defaultLLMType := defaultLLMType
        this.contextManager := contextManager
        if (defaultSystemPrompt)
            this.defaultSystemPrompt := defaultSystemPrompt

        Loop this.MAX_SESSIONS
            this.sessions.Push(Session(this.defaultSystemPrompt, this.defaultLLMType))
    }

    GetCurrentSession() => this.sessions[this.currentSessionIndex]

    GetCurrentSessionMessages() => this.GetCurrentSession().GetCurrentMessages()

    GetSessionMessages(index) => this.sessions[index].GetCurrentMessages()

    AddMessages(messages) => this.GetCurrentSession().AddMessages(messages)

    AddMessagesToSession(index, messages) => this.sessions[index].AddMessages(messages)

    CreateHistoryBranch(upToIndex) => this.GetCurrentSession().CreateHistoryBranch(upToIndex)

    NavigateHistoryPrevious() => this.GetCurrentSession().NavigateHistoryPrevious()

    NavigateHistoryNext() => this.GetCurrentSession().NavigateHistoryNext()

    GetHistoryInfo() => this.GetCurrentSession().GetHistoryInfo()

    GetCurrentSessionContext() => this.GetSessionContext(this.currentSessionIndex)

    GetSessionContext(index) => this.sessions[index].context

    SetCurrentSessionContext(newContext) => this.GetCurrentSession().context := newContext

    GetCurrentSessionLLMType() => this.GetSessionLLMType(this.currentSessionIndex)

    GetSessionLLMType(index) => this.sessions[index].llmType

    SetCurrentSessionLLMType(index) => this.GetCurrentSession().llmType := index

    GetCurrentSessionSystemPrompt() => this.GetSessionSystemPrompt(this.currentSessionIndex)

    GetSessionSystemPrompt(index) => this.sessions[index].systemPromptIndex

    SetCurrentSessionSystemPrompt(index) => this.GetCurrentSession().systemPromptIndex := index

    UpdateSystemPromptContent(systemPromptContent) => this.UpdateSystemPromptContentForSession(this.currentSessionIndex, systemPromptContent)

    UpdateSystemPromptContentForSession(index, systemPromptContent) => this.sessions[index].UpdateSystemPrompt(systemPromptContent)

    SwitchSession(newIndex) {
        if (newIndex > 0 && newIndex <= this.MAX_SESSIONS) {
            this.currentSessionIndex := newIndex
            return true
        }
        return false
    }

    ResetCurrentSession() => this.GetCurrentSession().ResetSesssion(this.defaultSystemPrompt)

    ClearCurrentMessages() => this.GetCurrentSession().ResetHistory(this.defaultSystemPrompt)

    ClearCurrentContext() => this.GetCurrentSession().context := []

    SetAnswerSize(size) => this.answerSize := size

    SetBatchMode(enabled) => this.batchModeEnabled := enabled

    FormatMessagesForCompressionForSession(index) {
        messages := this.GetSessionMessages(index)
        formattedText := ""

        i := 2
        loop messages.Length - 1 {
            msg := messages[i]
            roleLabel := msg.Role == "user" ? "User" :
                msg.Role == "assistant" ? "Assistant" :
                msg.Role == "tool" ? "Tool" : msg.Role

            messageText := msg.GetText()
            formattedText .= roleLabel ": " messageText "`n`n"
            i++
        }

        return formattedText
    }

    FormatMessagesForCompression() {
        return this.FormatMessagesForCompressionForSession(this.currentSessionIndex)
    }

    ReplaceWithCompressedForSession(index, compressedMsg) {
        messages := this.GetSessionMessages(index)
        systemMsg := messages[1]

        this.sessions[index].ResetHistory(this.defaultSystemPrompt)

        current := this.GetSessionMessages(index)
        current[1] := systemMsg
        current.Push(compressedMsg)
    }

    ReplaceWithCompressed(compressedMsg) {
        this.ReplaceWithCompressedForSession(this.currentSessionIndex, compressedMsg)
    }

    GetMessagesExcludingBatchForSession(index) {
        allMessages := this.GetSessionMessages(index)
        filteredMessages := []

        for msg in allMessages {
            isBatch := (msg.AdditionalProperties.Has("isBatchMode") && msg.AdditionalProperties["isBatchMode"])
                    || (msg.AdditionalProperties.Has("isBatchResponse") && msg.AdditionalProperties["isBatchResponse"])

            if (!isBatch)
                filteredMessages.Push(msg)
        }
        return filteredMessages
    }

    GetMessagesExcludingBatch() {
        return this.GetMessagesExcludingBatchForSession(this.currentSessionIndex)
    }

    AddContextItems(items) {
        addedAny := false
        context := this.GetCurrentSessionContext()

        for item in items {
            if !this.IsContentDuplicate(item) {
                context.Push(ContextItem(item))
                addedAny := true
            }
        }

        if (addedAny)
            this.SetCurrentSessionContext(context)

        return addedAny
    }

    UpdateContextItem(index, newItemValue) {
        context := this.GetCurrentSessionContext()
        if (index > 0 && index <= context.Length) {
            context[index].Value := newItemValue
            return true
        }
        return false
    }

    SetContextItemChecked(index, checked) {
        context := this.GetCurrentSessionContext()
        if (index > 0 && index <= context.Length) {
            context[index].Checked := checked
            return true
        }
        return false
    }

    IsContextItemChecked(index) {
        context := this.GetCurrentSessionContext()
        if (index > 0 && index <= context.Length)
            return context[index].Checked
        return true
    }

    HasToolResponse(message) {
        toolCalls := this.GetToolCalls(message)
        if (toolCalls.Length = 0)
            return false

        messages := this.GetCurrentSessionMessages()
        for toolCall in toolCalls {
            for msg in messages {
                if (msg.Role = "tool") {
                    for part in msg.Contents {
                        if (part is FunctionResultContent && part.CallId = toolCall.Id)
                            return true
                    }
                }
            }
        }
        return false
    }

    GetToolCalls(msg) {
        toolCalls := []
        for part in msg.Contents {
            if (part is FunctionCallContent)
                toolCalls.Push(part)
        }
        return toolCalls
    }

    HasToolCalls(message) {
        for part in message.Contents {
            if (part is FunctionCallContent)
                return true
        }
        return false
    }

    HasUnexecutedToolCallsForSession(index) {
        messages := this.GetSessionMessages(index)
        for msg in messages {
            if (this.HasToolCalls(msg)) {
                toolCalls := this.GetToolCalls(msg)
                for toolCall in toolCalls {
                    if (!this.IsToolCallExecutedInSession(index, toolCall.Id))
                        return true
                }
            }
        }
        return false
    }

    HasUnexecutedToolCalls() {
        return this.HasUnexecutedToolCallsForSession(this.currentSessionIndex)
    }

    IsToolCallExecutedInSession(index, toolCallId) {
        messages := this.GetSessionMessages(index)
        for m in messages {
            if (m.Role == "tool") {
                for part in m.Contents {
                    if (part is FunctionResultContent && part.CallId == toolCallId)
                        return true
                }
            }
        }
        return false
    }

    IsToolCallExecuted(toolCallId) {
        return this.IsToolCallExecutedInSession(this.currentSessionIndex, toolCallId)
    }

    UpdateMessage(index, newContent) {
        messages := this.GetCurrentSessionMessages()
        if (index > 0 && index <= messages.Length) {
            msg := messages[index]
            msg.Contents := [TextContent(newContent)]
            return true
        }
        return false
    }

    UpdateMessageText(index, newContent) {
        messages := this.GetCurrentSessionMessages()
        if (index > 0 && index <= messages.Length) {
            msg := messages[index]
            newContents := []
            hasTextParts := false

            ; 1. Check if the text starts with a thinking block
            ; The PresentationService uses 6 or 8 backticks. We'll generically match ```...+thinking
            thinkingContent := ""
            mainContent := newContent

            if (RegExMatch(newContent, "^(``{3,})thinking\n([\s\S]*?)\n\1\n{1,2}([\s\S]*)$", &match)) {
                thinkingContent := match[2]
                mainContent := match[3]
            }

            ; 2. Update the thinking property
            if (thinkingContent != "") {
                msg.AdditionalProperties["thinking"] := thinkingContent
            } else if (msg.AdditionalProperties.Has("thinking")) {
                ; If they deleted the thinking block entirely, remove it
                msg.AdditionalProperties.Delete("thinking")
            }

            ; 3. Update the text contents safely keeping images/tools intact
            for part in msg.Contents {
                if (part is TextContent) {
                    if (!hasTextParts) {
                        newContents.Push(TextContent(mainContent))
                        hasTextParts := true
                    }
                } else {
                    newContents.Push(part)
                }
            }

            if (!hasTextParts) {
                newContents.InsertAt(1, TextContent(mainContent))
            }

            msg.Contents := newContents
            return true
        }
        return false
    }

    GetMessageText(message) => message.GetText()

    GetUserMessageTextWithoutContext(message) {
        if (message.Role == "user" && message.AdditionalProperties.Has("hasContext")
            && message.AdditionalProperties["hasContext"]) {
            messages := this.GetCurrentSessionMessages()
            isFirstUserMsg := false
            for msg in messages {
                if (msg.Role == "user") {
                    isFirstUserMsg := (msg == message)
                    break
                }
            }

            if (isFirstUserMsg) {
                text := ""
                for i, part in message.Contents {
                    if (i > 1 && part is TextContent) {
                        if (text != "")
                            text .= "`n"
                        text .= part.Text
                    }
                }
                return text
            }
        }

        return message.GetText()
    }

    DeleteMessage(index) {
        messages := this.GetCurrentSessionMessages()
        if (index > 1 && index <= messages.Length) {
            messages.RemoveAt(index)
            return true
        }
        return false
    }

    ExportSessionState() => this.GetCurrentSession().ToObject()

    ConvertMapToObject(value) {
        if (Type(value) = "Map") {
            obj := {}
            for key, val in value
                obj.%key% := this.ConvertMapToObject(val)
            return obj
        } else if (Type(value) = "Array") {
            arr := []
            for item in value
                arr.Push(this.ConvertMapToObject(item))
            return arr
        } else {
            return value
        }
    }

    ImportSessionState(state) {
        isMap := Type(state) = "Map"

        hasContext := isMap ? state.Has("context") : state.HasOwnProp("context")
        hasLLMType := isMap ? state.Has("llmType") : state.HasOwnProp("llmType")
        hasSystemPrompt := isMap ? state.Has("systemPrompt") : state.HasOwnProp("systemPrompt")

        if (!hasContext || !hasLLMType || !hasSystemPrompt)
            throw Error("Invalid session state file")

        this.sessions[this.currentSessionIndex] := Session.FromObject(state, ObjBindMethod(this, "ConvertMapToObject"))
        return true
    }

    BuildUserMessage(userMessageContent, imagePaths) {
        contentParts := []

        if (imagePaths.Length > 0) {
            if (userMessageContent != "")
                contentParts.Push(TextContent(userMessageContent))

            for imageValue in imagePaths {
                if (RegExMatch(imageValue, "i)^data:image/")) {
                    contentParts.Push(ImageContent(imageValue))
                } else if (InStr(imageValue, "http") == 1) {
                    contentParts.Push(ImageContent(imageValue))
                } else {
                    base64Image := FileService.GetFileAsBase64(imageValue)
                    if (base64Image != "") {
                        extension := SubStr(imageValue, InStr(imageValue, ".", , -1) + 1)
                        mimeType := "image/" . extension
                        contentParts.Push(ImageContent(base64Image, mimeType))
                    }
                }
            }
        } else {
            if (userMessageContent != "")
                contentParts.Push(TextContent(userMessageContent))
        }

        return contentParts
    }

    HasVal(haystack, needle) {
        for index, value in haystack {
            if (value = needle)
                return true
        }
        return false
    }

    CheckContentInMessages(messages, newContent) {
        for msg in messages {
            if (InStr(msg.GetText(), newContent))
                return true
        }
        return false
    }

    IsContentDuplicate(newContent) {
        if (newContent = "")
            return true

        currentContext := this.GetCurrentSessionContext()
        for item in currentContext {
            if (item.Value = newContent)
                return true
        }

        if (this.CheckContentInMessages(this.GetCurrentSessionMessages(), newContent))
            return true

        return false
    }

    GetCheckedImages() {
        images := []
        context := this.GetCurrentSessionContext()
        for index, item in context {
            if (item.Checked && this.contextManager.IsImage(item.Value)) {
                checkedValue := item.Value
                images.Push(checkedValue)
            }
        }
        return images
    }

    GetCheckedContextItems() {
        checkedItems := []
        context := this.GetCurrentSessionContext()
        for index, item in context {
            if (item.Checked)
                checkedItems.Push(item.Value)
        }
        return checkedItems
    }

    HasAnyCheckedItem() {
        context := this.GetCurrentSessionContext()
        for item in context {
            if (item.Checked)
                return true
        }
        return false
    }

    UncheckAllContext() {
        context := this.GetCurrentSessionContext()
        changed := false

        for index, item in context {
            if (item.Checked) {
                this.SetContextItemChecked(index, false)
                changed := true
            }
        }
        return changed
    }

    GetCurrentProcessingState() => this.GetCurrentSession().processingState

    SetCurrentProcessingState(state) => this.GetCurrentSession().processingState := state
}
