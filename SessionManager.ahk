#Include FileUtils.ahk
#Include LLM\Types.ahk

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

    __New(defaultLLMType := 1, defaultSystemPrompt := "") {
        this.defaultLLMType := defaultLLMType
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

    GetMessageAsString(message) {
        ; Check for audio content
        audioData := message.GetAudio()
        if (audioData != "") {
            return this.FormatAudioMessage(audioData)
        }
        
        ; Check for tool calls and results
        toolCallTexts := []
        for part in message.Contents {
            if (part is FunctionCallContent) {
                toolCallTexts.Push(this.FormatToolCallMessage(part))
            }
            if (part is FunctionResultContent) {
                return part.Result
            }
        }
        
        if (toolCallTexts.Length > 0) {
            finalText := ""
            for text in toolCallTexts {
                if (finalText != "")
                    finalText .= "`n"
                finalText .= text
            }
            return finalText
        }
        
        ; Get text content and check for thinking
        text := message.GetText()
        if (message.AdditionalProperties.Has("thinking") && message.AdditionalProperties["thinking"] != "") {
            ; Use 4 backticks for fence if content contains 3 backticks (to prevent breaking markdown rendering)
            thinkingContent := message.AdditionalProperties["thinking"]
            fence := InStr(thinkingContent, "``````") ? "````````" : "``````"
            text := fence . "thinking`n" . thinkingContent . "`n" . fence . "`n`n" . text
        }
        
        ; Check if has images
        hasImage := false
        for part in message.Contents {
            if (part is ImageContent) {
                hasImage := true
                break
            }
        }
        
        return hasImage ? text . " [Image]" : text
    }

    FormatAudioMessage(audioLink) {
        audioBase64 := FileUtils.GetFileAsBase64(audioLink)
        return '<audio controls><source src="data:audio/wav;base64,' audioBase64 '" type="audio/wav"></audio>'
    }



    FormatToolCallMessage(toolCall) {
        return toolCall.Name "(" JSON.Stringify(toolCall.Arguments) ")"
    }

    /**
     * Format messages for compression by creating a conversation transcript
     * @returns String representation of all messages for compression
     */
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
            
            messageText := this.GetMessageAsString(msg)
            formattedText .= roleLabel ": " messageText "`n`n"
            i++
        }
        
        return formattedText
    }

    GetCurrentSessionMessages() {
        return this.sessionMessages[this.currentSessionIndex]
    }

    GetCurrentSessionMessagesAsStrings() {
        messages := []
        allMessages := this.GetCurrentSessionMessages()
        
        ; Find first user message and check for context
        firstUserMsg := ""
        firstUserIndex := 0
        for i, message in allMessages {
            if (message.Role == "user") {
                firstUserMsg := message
                firstUserIndex := i
                break
            }
        }
        
        ; Check if context exists in first user message
        hasContext := false
        if (firstUserMsg && firstUserMsg.AdditionalProperties.Has("hasContext") 
            && firstUserMsg.AdditionalProperties["hasContext"]) {
            hasContext := true
        }
        
        ; Build messages array
        for i, message in allMessages {
            roleEmoji := message.Role == "system" ? "⚙️" :
                message.Role == "user" ? "👤" :
                message.Role == "assistant" ? "🤖" :
                message.Role == "tool" ? "🛠️" : message.Role

            ; If this is the first user message with context, exclude context from display
            if (hasContext && i == firstUserIndex) {
                ; Add user message without context
                userContent := ""
                for j, part in message.Contents {
                    if (j > 1 && part is TextContent) {
                        if (userContent != "")
                            userContent .= "`n"
                        userContent .= part.Text
                    }
                }
                
                ; Check if has images
                hasImage := false
                for part in message.Contents {
                    if (part is ImageContent) {
                        hasImage := true
                        break
                    }
                }
                
                if (userContent == "" && !hasImage) {
                    userContent := "(empty message)"
                }
                
                result := { role: roleEmoji, content: hasImage ? userContent . " [Image]" : userContent }
            } else {
                ; Regular message
                result := { role: roleEmoji, content: this.GetMessageAsString(message) }
            }

            ; Add additional properties from ChatMessage
            if (message.AdditionalProperties.Has("duration")) {
                result.duration := message.AdditionalProperties["duration"]
            }
            if (message.AdditionalProperties.Has("tokens")) {
                result.tokens := message.AdditionalProperties["tokens"]
            }
            messages.Push(result)
        }
        return messages
    }

    GetCurrentSessionContext() {
        return this.sessionContexts[this.currentSessionIndex]
    }

    SetCurrentSessionContext(newContext) {
        this.sessionContexts[this.currentSessionIndex] := newContext
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

        return {
            messages: messages,
            context: this.sessionContexts[this.currentSessionIndex],
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

        this.sessionMessages[this.currentSessionIndex] := chatMessages
        this.sessionContexts[this.currentSessionIndex] := this.ConvertMapToObject(context)
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
                    base64Image := FileUtils.GetFileAsBase64(imageValue)
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
}
