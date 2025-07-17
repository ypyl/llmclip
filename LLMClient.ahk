#Requires AutoHotkey 2.0
#Include <Json>
#Include "ComSpecTool.ahk"
#Include "FileSystemTool.ahk"

class LLMClient {
    ; Private properties
    settings := {}
    tempDir := A_Temp "\llmclip"
    comSpecTool := ComSpecTool()
    fileSystemTool := FileSystemTool()

    __New(settings) {
        this.settings := settings

        ; Ensure temp directory exists
        if !DirExist(this.tempDir)
            DirCreate(this.tempDir)
    }

    Call(messages) {
        try {
            selectedSettings := this.settings
            curl := selectedSettings["curl"]
            selectedLLMType := selectedSettings.Has("type") ? selectedSettings["type"] : "groq"

            ; Prepare request body
            body := this.GetRequestBody(selectedLLMType, messages, selectedSettings)

            ; Create temporary files for input/output
            inputFile := this.tempDir "\request.json"

            ; Handle audio output differently
            if (InStr(selectedLLMType, "gr-audio") = 1) {
                outputFile := this.tempDir "\response.wav"
            } else {
                outputFile := this.tempDir "\response.json"
            }

            ; Write request body to temp file
            try FileDelete(inputFile)
            FileAppend(JSON.Dump(body), inputFile)

            ; Prepare curl command
            curlCmd := Format(curl, inputFile, outputFile)

            ; Execute curl
            RunWait(curlCmd, , "Hide")

            ; Show error if response file doesn't exist
            if (!FileExist(outputFile)) {
                throw Error("No response file created")
            }

            ; Handle audio response
            if (InStr(selectedLLMType, "gr-audio") = 1) {
                return [this.CreateMessageFromResponse({ type: "audio", content: outputFile })]
            }

            ; Read response for non-audio types
            if FileExist(outputFile) {
                response := FileRead(outputFile, "UTF-8")
                if (response != "") {
                    responseData := this.ParseResponse(response, selectedLLMType)
                    messages := []
                    for data in responseData {
                        messages.Push(this.CreateMessageFromResponse(data))
                    }
                    return messages
                }
            }
            throw Error("No response received")

        } catch as e {
            newMessage := { role: "assistant", content: e.Message }
            return [newMessage]
        } finally {
            ; Cleanup temp files but don't delete audio files
            try {
                FileDelete(inputFile)

                ; Only delete JSON response files, not audio files
                if (!InStr(selectedLLMType, "gr-audio") = 1) {
                    FileDelete(outputFile)
                }
            }
        }
    }

    CreateMessageFromResponse(responseData) {
        if (responseData.type = "tool_call") {
            ; Create proper assistant message with tool_calls
            return {
                role: "assistant",
                content: "",  ; Empty content as we have tool_calls
                tool_calls: [{
                    id: responseData.content.id,
                    type: "function",
                    function: {
                        name: responseData.content.name,
                        arguments: responseData.content.arguments
                    }
                }]
            }
        } else if (responseData.type = "audio") {
            return {
                role: "assistant",
                content: "",
                audio: {
                    link: responseData.content,
                }
            }
        } else {
            return { role: "assistant", content: responseData.content }
        }
    }

    GetRequestBody(type, messages, settings) {
        if (InStr(type, "gr-audio") = 1)
            return this.GetGroqAudioBody(messages, settings)
        else if (InStr(type, "gr") = 1 || InStr(type, "az") = 1)
            return this.GetGroqAzureBody(messages, settings)
        else if (InStr(type, "ol-") = 1)
            return this.GetOllamaAILikeBody(messages, settings)
        else if (InStr(type, "go") = 1)
            return this.GetGoogleBody(messages, settings)
        throw Error("Unknown model type: " type)
    }

    FilterMessages(messages) {
        ; Filter out audio messages and their corresponding user prompts
        filteredMessages := []
        skipNextUser := false

        ; Process messages in reverse order to identify audio messages first
        i := messages.Length
        Loop messages.Length {
            msg := messages[i]

            ; If this is an audio message, skip it and mark to skip the next user message
            if (msg.role = "assistant" && msg.content = "" && msg.HasProp("audio")) {
                skipNextUser := true
                i--
                continue
            }

            ; Skip the user message that triggered an audio response
            if (skipNextUser && msg.role = "user") {
                skipNextUser := false
                i--
                continue
            }

            ; Insert at beginning to preserve original order
            filteredMessages.InsertAt(1, msg)
            i--
        }

        return filteredMessages
    }

    GetGroqAudioBody(messages, settings) {
        ; For audio generation, we use the last user message as input text
        lastUserMessage := ""
        Loop messages.Length
        {
            idx := messages.Length - A_Index + 1
            if (messages[idx].role = "user") {
                lastUserMessage := messages[idx].content
                break
            }
        }

        body := Map()
        body["model"] := settings.Get("model", "playai-tts")
        body["input"] := lastUserMessage
        ; https://console.groq.com/docs/text-to-speech#available-english-voices
        body["voice"] := settings.Get("voice", "Arista-PlayAI")
        body["response_format"] := settings.Get("response_format", "wav")

        return body
    }

    GetGroqAzureBody(messages, settings) {
        body := Map()
        if (model := settings.Get("model", ""))
            body["model"] := model

        ; Apply message filtering and reordering
        filteredMessages := this.FilterMessages(messages)
        reorderedMessages := this.ReorderToolCallsAndResults(filteredMessages)

        body["messages"] := reorderedMessages
        body["temperature"] := settings.Get("temperature", 0.7)

        ; Add ComSpec tool
        if (toolEnablesd := settings.Get("tools", true))
            body["tools"] := [this.comSpecTool.GetOpenAiToolDefinition(), this.fileSystemTool.GetOpenAiToolDefinition()]

        return body
    }

    ReorderToolCallsAndResults(messages) {
        ; Create a map of tool call IDs to their positions
        toolCallPositions := Map()
        reorderedMessages := []

        ; First pass: identify tool calls and build the position map
        Loop messages.Length {
            msg := messages[A_Index]

            ; If this is an assistant message with tool calls
            if (msg.role = "assistant" && msg.content = "" && msg.HasProp("tool_calls")) {
                ; Record the position of each tool call
                for toolCall in msg.tool_calls {
                    if (toolCall.HasProp("id")) {
                        toolCallPositions[toolCall.id] := reorderedMessages.Length + 1
                    }
                }
            }

            ; Add all non-tool messages to the result
            if (msg.role != "tool") {
                reorderedMessages.Push(msg)
            }
        }

        ; Second pass: insert tool results after their corresponding tool calls
        Loop messages.Length {
            msg := messages[A_Index]

            ; If this is a tool result message
            if (msg.role = "tool" && msg.HasProp("tool_call_id")) {
                toolCallId := msg.tool_call_id

                ; If we have a record of the corresponding tool call
                if (toolCallPositions.Has(toolCallId)) {
                    insertPosition := toolCallPositions[toolCallId]

                    ; Insert the tool result right after its tool call
                    reorderedMessages.InsertAt(insertPosition + 1, msg)

                    ; After inserting, remove this ID from the map and
                    ; increment all positions for remaining tool calls
                    toolCallPositions.Delete(toolCallId)

                    ; Update positions for all remaining tool calls
                    for id, pos in toolCallPositions {
                        if (pos > insertPosition) {
                            toolCallPositions[id] := pos + 1
                        }
                    }
                } else {
                    ; If we can't find the corresponding tool call, just add at the end
                    reorderedMessages.Push(msg)
                }
            }
        }

        return reorderedMessages
    }

    GetOllamaAILikeBody(messages, settings) {
        body := Map()
        body["model"] := settings["model"]
        body["options"] := Map(
            "temperature", settings.Get("temperature", 0.7),
        )
        body["stream"] := JSON.False
        body["messages"] := this.FilterMessages(messages)
        return body
    }

    GetGoogleBody(messages, settings) {
        body := Map()
        contents := []
        systemMessage := ""

        ; Filter messages to remove audio messages and their prompts
        filteredMessages := this.FilterMessages(messages)

        ; First, find and handle system message
        for msg in filteredMessages {
            if (msg.role = "system") {
                systemMessage := msg
                break
            }
        }

        ; Add system instruction if present
        if (systemMessage) {
            body["system_instruction"] := {
                parts: [{
                    text: systemMessage.content
                }]
            }
        }

        ; Add other messages to contents
        for i, msg in filteredMessages {
            if (msg.role == "system") {
                continue ; Skip system messages, already handled
            }
            if (msg.role = "tool") {
                ; Group all tool responses that belong to the same assistant message
                if (i < filteredMessages.Length && filteredMessages[i + 1].role = "tool") {
                    continue ; Skip this one, we'll handle it in the next pass
                }

                ; Collect all tool responses that belong to the previous assistant message
                toolResponses := []
                currentIndex := i

                ; Work backwards to collect all tool responses for this group
                while (currentIndex > 0 && filteredMessages[currentIndex].role = "tool") {
                    toolResponses.InsertAt(1, {
                        functionResponse: {
                            id: filteredMessages[currentIndex].tool_call_id,
                            name: "execute_command", ; or the appropriate function name
                            response: { result: filteredMessages[currentIndex].content }
                        }
                    })
                    currentIndex--
                }

                ; Add all tool responses as parts of a single user message
                if (toolResponses.Length > 0) {
                    contents.Push({
                        role: "user",
                        parts: toolResponses
                    })
                }
            } else if (msg.role = "assistant") {
                if (msg.content = "" && msg.HasProp("tool_calls")) {
                    ; Skip if this is not the last of consecutive assistant messages with tool calls
                    if (i < filteredMessages.Length &&
                        filteredMessages[i + 1].role = "assistant" &&
                        filteredMessages[i + 1].content = "" &&
                        filteredMessages[i + 1].HasProp("tool_calls")) {
                        continue
                    }

                    ; Collect all function calls from consecutive assistant messages
                    functionCalls := []
                    currentIndex := i

                    ; Work backwards to collect all tool calls from consecutive assistant messages
                    while (currentIndex > 0 &&
                        filteredMessages[currentIndex].role = "assistant" &&
                        filteredMessages[currentIndex].content = "" &&
                        filteredMessages[currentIndex].HasProp("tool_calls")) {

                        ; Add all tool calls from this message
                        for toolCall in filteredMessages[currentIndex].tool_calls {
                            functionCalls.InsertAt(1, {
                                functionCall: {
                                    id: toolCall.id,
                                    name: toolCall.function.name,
                                    args: JSON.Parse(toolCall.function.arguments),
                                }
                            })
                        }
                        currentIndex--
                    }

                    ; Add all function calls as parts of a single model message
                    if (functionCalls.Length > 0) {
                        contents.Push({
                            role: "model",
                            parts: functionCalls
                        })
                    }
                } else {
                    contents.Push({
                        role: "model",
                        parts: [{
                            text: msg.content
                        }]
                    })
                }
            } else if (msg.role = "user" && !(i > 0 && filteredMessages[i - 1].role = "tool")) {
                ; Only add user messages that aren't immediately after tool messages
                ; (those would be handled by the tool response logic)
                contents.Push({
                    role: msg.role,
                    parts: [{
                        text: msg.content
                    }]
                })
            }
        }

        body["contents"] := contents
        if (toolEnablesd := settings.Get("tools", true))
            body["tools"] := [this.comSpecTool.GetGeminiToolDefinition()]
        body["generationConfig"] := {
            stopSequences: settings.Get("stopSequences", ["Title"]),
            temperature: settings.Get("temperature", 1.0),
            maxOutputTokens: settings.Get("maxOutputTokens", 800),
            topP: settings.Get("topP", 0.8),
            topK: settings.Get("topK", 10)
        }
        return body
    }

    ParseResponse(response, type := "") {
        obj := JSON.Load(response)
        results := []

        ; Handle Google's response format
        if (obj.Has("candidates") && obj["candidates"].Length > 0) {
            candidate := obj["candidates"][1]
            if (candidate.Has("content") && candidate["content"].Has("parts") && candidate["content"]["parts"].Length > 0) {
                ; Check for function calls in parts
                parts := candidate["content"]["parts"]
                for part in parts {
                    if (part.Has("functionCall")) {
                        functionCall := part["functionCall"]
                        results.Push({
                            type: "tool_call",
                            content: {
                                id: functionCall.Get("id", ""),
                                name: functionCall["name"],
                                arguments: JSON.Stringify(functionCall["args"])
                            }
                        })
                    } else if (part.Has("text")) {
                        results.Push({ type: "text", content: part["text"] })
                    }
                }
            }
        }

        ; Handle format with direct message object
        if (obj.Has("message") && obj["message"].Has("content")) {
            results.Push({ type: "text", content: obj["message"]["content"] })
        }

        ; Handle OpenAI-style format
        if (obj.Has("choices") && obj["choices"].Length > 0) {
            choice := obj["choices"][1]
            if (choice.Has("message")) {
                message := choice["message"]

                ; Check for tool calls
                if (message.Has("tool_calls") && message["tool_calls"].Length > 0) {
                    for toolCall in message["tool_calls"] {
                        results.Push({
                            type: "tool_call",
                            content: {
                                id: toolCall["id"],
                                name: toolCall["function"]["name"],
                                arguments: toolCall["function"]["arguments"]
                            }
                        })
                    }
                }

                ; Handle regular text response
                if (message.Has("content") && message["content"] != "") {
                    results.Push({ type: "text", content: message["content"] })
                }
            }
        }

        if (results.Length > 0) {
            return results
        }

        throw Error(response)
    }
}
