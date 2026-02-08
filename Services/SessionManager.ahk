#Include LLM\Types.ahk
#Include ContextItem.ahk

class SessionManager {
    currentSessionIndex := 1
    MAX_SESSIONS := 5
    sessionNames := ["Session 1", "Session 2", "Session 3", "Session 4", "Session 5"]
    sessionMessages := []
    sessionContexts := []
    sessionLLMTypes := []
    sessionSystemPrompts := []

    ; Store default values to be used when no settings are provided
    defaultSystemPrompt := "You are a helpful assistant. Be concise and direct in your responses."
    defaultLLMType := 1
    contextManager := ""

    __New(defaultLLMType := 1, defaultSystemPrompt := "", contextManager := "") {
        this.defaultLLMType := defaultLLMType
        this.contextManager := contextManager
        if (defaultSystemPrompt)
            this.defaultSystemPrompt := defaultSystemPrompt

        ; Initialize session arrays with ChatMessage instances
        Loop this.MAX_SESSIONS {
            this.sessionMessages.Push([
                ChatMessage("system", [TextContent(this.defaultSystemPrompt)])
            ])
            this.sessionContexts.Push([])
            this.sessionLLMTypes.Push(this.defaultLLMType)
            this.sessionSystemPrompts.Push(1)
        }
    }

    FormatMessagesForCompression() {
        messages := this.GetCurrentSessionMessages()
        formattedText := ""
        
        ; Skip the system message (index 1) and format the rest
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

    GetCurrentSessionMessages() {
        return this.sessionMessages[this.currentSessionIndex]
    }

    /**
     * Get messages for the current session, excluding those marked as batch mode or batch response
     * @returns Array of ChatMessage instances
     */
    GetMessagesExcludingBatch() {
        allMessages := this.GetCurrentSessionMessages()
        filteredMessages := []
        
        for msg in allMessages {
            isBatch := (msg.AdditionalProperties.Has("isBatchMode") && msg.AdditionalProperties["isBatchMode"])
                    || (msg.AdditionalProperties.Has("isBatchResponse") && msg.AdditionalProperties["isBatchResponse"])
            
            if (!isBatch) {
                filteredMessages.Push(msg)
            }
        }
        return filteredMessages
    }



    GetCurrentSessionContext() {
        return this.sessionContexts[this.currentSessionIndex]
    }

    SetCurrentSessionContext(newContext) {
        this.sessionContexts[this.currentSessionIndex] := newContext
    }

    /**
     * Add multiple items to the current session context, filtering duplicates.
     * @param items - Array of items to add
     * @returns Boolean indicating if any items were added
     */
    AddContextItems(items) {
        addedAny := false
        context := this.GetCurrentSessionContext()
        
        for item in items {
            if !this.IsContentDuplicate(item) {
                context.Push(ContextItem(item))
                addedAny := true
            }
        }

        if (addedAny) {
            this.SetCurrentSessionContext(context)
        }

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
        if (index > 0 && index <= context.Length) {
            return context[index].Checked
        }
        return true ; Default
    }

    GetCurrentSessionLLMType() {
        return this.sessionLLMTypes[this.currentSessionIndex]
    }

    GetCurrentSessionSystemPrompt() {
        return this.sessionSystemPrompts[this.currentSessionIndex]
    }

    SetCurrentSessionLLMType(index) {
        this.sessionLLMTypes[this.currentSessionIndex] := index
    }

    SetCurrentSessionSystemPrompt(index) {
        this.sessionSystemPrompts[this.currentSessionIndex] := index
    }

    SwitchSession(newIndex) {
        if (newIndex > 0 && newIndex <= this.MAX_SESSIONS) {
            this.currentSessionIndex := newIndex
            return true
        }
        return false
    }

    UpdateSystemPromptContent(systemPromptContent) {
        if (this.sessionMessages[this.currentSessionIndex].Length > 0) {
            firstMsg := this.sessionMessages[this.currentSessionIndex][1]
            if (firstMsg.Role == "system") {
                ; Update the text content
                firstMsg.Contents := [TextContent(systemPromptContent)]
            }
        }
    }

    ResetCurrentSession() {
        this.ClearCurrentMessages()
        this.ClearCurrentContext()
    }

    ClearCurrentMessages() {
        this.sessionMessages[this.currentSessionIndex] := [
            ChatMessage("system", [TextContent(this.defaultSystemPrompt)])
        ]
    }

    ClearCurrentContext() {
        this.sessionContexts[this.currentSessionIndex] := []
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
                        if (part is FunctionResultContent && part.CallId = toolCall.Id) {
                            return true
                        }
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

    HasUnexecutedToolCalls() {
        messages := this.GetCurrentSessionMessages()
        for msg in messages {
            if (this.HasToolCalls(msg)) {
                toolCalls := this.GetToolCalls(msg)
                for toolCall in toolCalls {
                    if (!this.IsToolCallExecuted(toolCall.Id)) {
                        return true
                    }
                }
            }
        }
        return false
    }

    IsToolCallExecuted(toolCallId) {
        messages := this.GetCurrentSessionMessages()
        for m in messages {
            if (m.Role == "tool") {
                for part in m.Contents {
                    if (part is FunctionResultContent && part.CallId == toolCallId) {
                        return true
                    }
                }
            }
        }
        return false
    }

    TruncateMessages(index) {
        if (index > 0 && index < this.sessionMessages[this.currentSessionIndex].Length) {
            ; Remove all messages after the specified index
            ; We loop from the end down to index + 1
            loopCount := this.sessionMessages[this.currentSessionIndex].Length - index
            Loop loopCount {
                this.sessionMessages[this.currentSessionIndex].Pop()
            }
            return true
        }
        return false
    }

    UpdateMessage(index, newContent) {
        if (index > 0 && index <= this.sessionMessages[this.currentSessionIndex].Length) {
            msg := this.sessionMessages[this.currentSessionIndex][index]
            msg.Contents := [TextContent(newContent)]
            return true
        }
        return false
    }

    GetMessageText(message) {
        return message.GetText()
    }

    /**
     * Get user message text without context
     * @param message - ChatMessage instance
     * @returns String content without context
     */
    GetUserMessageTextWithoutContext(message) {
        ; Check if this is a user message with context
        if (message.Role == "user" && message.AdditionalProperties.Has("hasContext") 
            && message.AdditionalProperties["hasContext"]) {
            ; Check if this is the first user message
            messages := this.GetCurrentSessionMessages()
            isFirstUserMsg := false
            for msg in messages {
                if (msg.Role == "user") {
                    isFirstUserMsg := (msg == message)
                    break
                }
            }
            
            if (isFirstUserMsg) {
                ; Extract text without first TextContent (context)
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
        
        ; Not first user message or no context - return all text
        return message.GetText()
    }


    DeleteMessage(index) {
        if (index > 1 && index <= this.sessionMessages[this.currentSessionIndex].Length) {
            this.sessionMessages[this.currentSessionIndex].RemoveAt(index)
            return true
        }
        return false
    }

    ExportSessionState() {
        ; Convert ChatMessage instances to plain objects for JSON serialization
        messages := []
        for msg in this.sessionMessages[this.currentSessionIndex] {
            messages.Push(msg.ToObject(true))
        }

        context := []
        for item in this.sessionContexts[this.currentSessionIndex] {
            context.Push(item.ToObject())
        }

        return {
            messages: messages,
            context: context,
            llmType: this.sessionLLMTypes[this.currentSessionIndex],
            systemPrompt: this.sessionSystemPrompts[this.currentSessionIndex]
        }
    }

    ; Helper method to convert Map objects (from JSON parser) to regular objects
    ConvertMapToObject(value) {
        if (Type(value) = "Map") {
            obj := {}
            for key, val in value {
                obj.%key% := this.ConvertMapToObject(val)
            }
            return obj
        } else if (Type(value) = "Array") {
            arr := []
            for item in value {
                arr.Push(this.ConvertMapToObject(item))
            }
            return arr
        } else {
            return value
        }
    }

    ImportSessionState(state) {
        ; Check if state is a Map (from JSON parser) or an Object
        isMap := Type(state) = "Map"

        ; Validate required properties exist
        hasMessages := isMap ? state.Has("messages") : state.HasOwnProp("messages")
        hasContext := isMap ? state.Has("context") : state.HasOwnProp("context")
        hasLLMType := isMap ? state.Has("llmType") : state.HasOwnProp("llmType")
        hasSystemPrompt := isMap ? state.Has("systemPrompt") : state.HasOwnProp("systemPrompt")

        if (!hasMessages || !hasContext || !hasLLMType || !hasSystemPrompt) {
            throw Error("Invalid session state file")
        }

        ; Get values and convert Maps to Objects if needed
        messages := isMap ? state["messages"] : state.messages
        context := isMap ? state["context"] : state.context
        llmType := isMap ? state["llmType"] : state.llmType
        systemPrompt := isMap ? state["systemPrompt"] : state.systemPrompt

        ; Convert messages to ChatMessage instances
        chatMessages := []
        for msg in messages {
            plainObj := this.ConvertMapToObject(msg)
            chatMessages.Push(ChatMessage.FromObject(plainObj))
        }

        ; Convert context to ContextItem instances
        chatContext := []
        for item in context {
            chatContext.Push(ContextItem.FromObject(item))
        }

        this.sessionMessages[this.currentSessionIndex] := chatMessages
        this.sessionContexts[this.currentSessionIndex] := chatContext
        this.sessionLLMTypes[this.currentSessionIndex] := llmType
        this.sessionSystemPrompts[this.currentSessionIndex] := systemPrompt

        return true
    }

    BuildUserMessage(userMessageContent, imagePaths) {
        contentParts := []

        if (imagePaths.Length > 0) {
            if (userMessageContent != "") {
                contentParts.Push(TextContent(userMessageContent))
            }

            for imageValue in imagePaths {
                if (RegExMatch(imageValue, "i)^data:image/")) {
                    ; Already data URI
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
            if (userMessageContent != "") {
                contentParts.Push(TextContent(userMessageContent))
            }
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

        ; Check in current session context
        currentContext := this.GetCurrentSessionContext()
        for item in currentContext {
            if (item.Value = newContent)
                return true
        }

        ; Check in chat history
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
            if (item.Checked) {
                checkedItems.Push(item.Value)
            }
        }
        return checkedItems
    }

    HasAnyCheckedItem() {
        context := this.GetCurrentSessionContext()
        for item in context {
            if (item.Checked) {
                return true
            }
        }
        return false
    }

    UncheckAllImages() {
        context := this.GetCurrentSessionContext()
        changed := false

        for index, item in context {
            if (this.contextManager.IsImage(item.Value) && item.Checked) {
                this.SetContextItemChecked(index, false)
                changed := true
            }
        }
        return changed
    }
}
