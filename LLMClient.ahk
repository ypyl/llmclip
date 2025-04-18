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
            outputFile := this.tempDir "\response.json"

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

            ; Read response
            if FileExist(outputFile) {
                response := FileRead(outputFile, "UTF-8")
                if (response != "") {
                    return this.ParseResponse(response, selectedLLMType)
                }
            }
            throw Error("No response received")

        } finally {
            ; Cleanup temp files
            try {
                FileDelete(inputFile)
                FileDelete(outputFile)
            }
        }
    }

    GetRequestBody(type, messages, settings) {
        if (type = "groq" || type = "azure")
            return this.GetGroqAzureBody(messages, settings)
        else if (InStr(type, "ol-") = 1)
            return this.GetOllamaAILikeBody(messages, settings)
        else if (type = "google")
            return this.GetGoogleBody(messages, settings)
        throw Error("Unknown model type: " type)
    }

    GetGroqAzureBody(messages, settings) {
        body := Map()
        if (model := settings.Get("model", ""))
            body["model"] := model
        body["messages"] := messages
        body["temperature"] := settings.Get("temperature", 0.7)

        ; Add ComSpec tool
        body["tools"] := [this.comSpecTool.GetOpenAiToolDefinition(), this.fileSystemTool.GetOpenAiToolDefinition()]

        return body
    }

    GetOllamaAILikeBody(messages, settings) {
        body := Map()
        body["model"] := settings["model"]
        body["options"] := Map(
            "temperature", settings.Get("temperature", 0.7),
        )
        body["stream"] := JSON.False
        body["messages"] := messages
        return body
    }

    GetGoogleBody(messages, settings) {
        body := Map()
        contents := []
        systemMessage := ""

        ; First, find and handle system message
        for msg in messages {
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
        for msg in messages {
            if (msg.role != "system") {
                if (msg.role = "tool") {
                    ; Handle tool response
                    contents.Push({
                        role: "user",
                        parts: [{
                            functionResponse: {
                                id: msg.tool_call_id,
                                name: "execute_command",
                                response: { result: msg.content }
                            }
                        }]
                    })
                } else if (msg.role = "assistant") {
                    if (msg.content = "" && msg.HasProp("tool_calls")) {
                        contents.Push({
                            role: "model",
                            parts: [{
                                functionCall: {
                                    id: msg.tool_calls[1].id,
                                    name: msg.tool_calls[1].function.name,
                                    args: JSON.Parse(msg.tool_calls[1].function.arguments),
                                }
                            }]
                        })
                        prevMsgAssistant := msg
                    } else {
                        contents.Push({
                            role: "model",
                            parts: [{
                                text: msg.content
                            }]
                        })
                    }
                } else {
                    contents.Push({
                        role: msg.role,
                        parts: [{
                            text: msg.content
                        }]
                    })
                }
            }
        }

        body["contents"] := contents
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

        ; Handle Google's response format
        if (obj.Has("candidates") && obj["candidates"].Length > 0) {
            candidate := obj["candidates"][1]
            if (candidate.Has("content") && candidate["content"].Has("parts") && candidate["content"]["parts"].Length > 0) {
                ; Check for function calls in parts
                parts := candidate["content"]["parts"]
                for part in parts {
                    if (part.Has("functionCall")) {
                        functionCall := part["functionCall"]
                        return {
                            type: "tool_call",
                            content: {
                                id: functionCall.Get("id", ""),
                                name: functionCall["name"],
                                arguments: JSON.Stringify(functionCall["args"])
                            }
                        }
                    }
                }
                ; If no function call found, return text content
                return { type: "text", content: parts[1]["text"] }
            }
        }

        ; Handle format with direct message object
        if (obj.Has("message") && obj["message"].Has("content")) {
            return { type: "text", content: obj["message"]["content"] }
        }

        ; Handle OpenAI-style format
        if (obj.Has("choices") && obj["choices"].Length > 0) {
            choice := obj["choices"][1]
            if (choice.Has("message")) {
                message := choice["message"]

                ; Check for tool calls
                if (message.Has("tool_calls") && message["tool_calls"].Length > 0) {
                    toolCall := message["tool_calls"][1]
                    return {
                        type: "tool_call",
                        content: {
                            id: toolCall["id"],
                            name: toolCall["function"]["name"],
                            arguments: toolCall["function"]["arguments"]
                        }
                    }
                }

                ; Handle regular text response
                if (message.Has("content")) {
                    return { type: "text", content: message["content"] }
                }
            }
        }

        throw Error("Unable to parse response")
    }
}
