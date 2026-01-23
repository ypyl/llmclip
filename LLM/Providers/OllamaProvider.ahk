#Include "BaseProvider.ahk"
#Include "..\PowerShellTool.ahk"
#Include "..\FileSystemTool.ahk"
#Include "..\WebSearchTool.ahk"
#Include "..\WebFetchTool.ahk"

class OllamaProvider extends BaseProvider {
    GetRequestBody(messages, settings) {
        body := Map()
        body["model"] := settings["model"]
        body["options"] := Map(
            "temperature", settings.Get("temperature", 0.7),
        )
        body["stream"] := JSON.False

        filteredMessages := this.FilterMessages(messages)
        ollamaMessages := []

        for msg in filteredMessages {
            newMsg := Map()
            newMsg["role"] := msg.Role

            ; Handle multimodal content
            textPart := msg.GetText()
            images := []

            for part in msg.Contents {
                if (part is ImageContent) {
                    ; Extract base64 from data URI if it's a data URI
                    if (part.Url != "" && InStr(part.Url, "data:") = 1) {
                        commaPos := InStr(part.Url, ",")
                        if (commaPos > 0) {
                            base64Data := SubStr(part.Url, commaPos + 1)
                            images.Push(base64Data)
                        }
                    } else if (part.Data != "") {
                        images.Push(part.Data)
                    }
                }
            }

            newMsg["content"] := textPart
            if (images.Length > 0) {
                newMsg["images"] := images
            }

            ; Handle tool calls (for history messages)
            if (msg.Role = "assistant" && msg.Contents.Length > 0) {
                toolCalls := []
                for part in msg.Contents {
                    if (part is FunctionCallContent) {
                        toolCall := Map(
                            "function", Map(
                                "name", part.Name,
                                "arguments", part.Arguments
                            )
                        )
                        toolCalls.Push(toolCall)
                    }
                }
                if (toolCalls.Length > 0) {
                    newMsg["tool_calls"] := toolCalls
                }
            } else if (msg.Role = "tool" && msg.Contents.Length > 0) {
                ; Ollama uses a slightly different format for tool results, usually message role "tool" is fine
                ; but content needs to be the result string
                newMsg["content"] := msg.GetText()
            }

            ollamaMessages.Push(newMsg)
        }

        body["messages"] := ollamaMessages

        ; Add tools
        enabledTools := []
        for t in settings.Get("tools", []) {
            if (t = "powerShellTool")
                enabledTools.Push(PowerShellTool.GetOpenAiToolDefinition())
            else if (t = "fileSystemTool")
                enabledTools.Push(FileSystemTool.GetOpenAiToolDefinition())
            else if (t = "web_search")
                enabledTools.Push(WebSearchTool.GetOpenAiToolDefinition())
            else if (t = "web_fetch")
                enabledTools.Push(WebFetchTool.GetOpenAiToolDefinition())
        }
        if (enabledTools.Length > 0)
            body["tools"] := enabledTools

        return body
    }

    ParseResponse(response) {
        obj := JSON.Load(response)
        results := []

        ; Handle format with direct message object (Ollama often returns this)
        ; Handle format with direct message object (Ollama often returns this)
        if (obj.Has("message")) {
            msgObj := obj["message"]
            chatMsg := ChatMessage("assistant", [])

            if (msgObj.Has("content")) {
                chatMsg.Contents.Push(TextContent(msgObj["content"]))
            }

            if (msgObj.Has("thinking")) {
                chatMsg.AdditionalProperties["thinking"] := msgObj["thinking"]
            }

            ; Add token usage
            if (obj.Has("usage") && obj["usage"].Has("total_tokens")) {
                chatMsg.AdditionalProperties["tokens"] := obj["usage"]["total_tokens"]
            }

            ; Check for tool calls
            if (msgObj.Has("tool_calls") && msgObj["tool_calls"].Length > 0) {
                for toolCall in msgObj["tool_calls"] {
                    ; Ollama might return function arguments as an object directly, no need to parse JSON if so
                    args := toolCall["function"]["arguments"]
                    if (Type(args) == "String") {
                        try {
                            args := JSON.Load(args)
                        }
                    }

                    funcCall := FunctionCallContent(
                        toolCall.Has("id") ? toolCall["id"] : "call_" . A_TickCount, ; Ollama might not return ID
                        toolCall["function"]["name"],
                        args
                    )
                    chatMsg.Contents.Push(funcCall)
                }
            }

            results.Push(chatMsg)
            return results
        }

        ; Fallback to OpenAI style if Ollama is using that (some versions might)
        if (obj.Has("choices") && obj["choices"].Length > 0) {
            choice := obj["choices"][1]
            if (choice.Has("message") && choice["message"].Has("content")) {
                chatMsg := ChatMessage("assistant", [TextContent(choice["message"]["content"])])

                ; Add token usage
                if (obj.Has("usage") && obj["usage"].Has("total_tokens")) {
                    chatMsg.AdditionalProperties["tokens"] := obj["usage"]["total_tokens"]
                }

                results.Push(chatMsg)
                return results
            }
        }

        throw Error(response)
    }
}
