#Include "BaseProvider.ahk"
#Include "..\PowerShellTool.ahk"
#Include "..\FileSystemTool.ahk"
#Include "..\WebSearchTool.ahk"
#Include "..\WebFetchTool.ahk"

class OpenAIProvider extends BaseProvider {

    GetRequestBody(messages, settings) {
        body := Map()
        if (model := settings.Get("model", ""))
            body["model"] := model

        ; Apply message filtering and reordering
        filteredMessages := this.FilterMessages(messages)
        reorderedMessages := this.ReorderToolCallsAndResults(filteredMessages)
        cleanedMessages := this.AdaptMessages(reorderedMessages)

        body["messages"] := cleanedMessages
        body["temperature"] := settings.Get("temperature", 0.7)

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

        if (obj.Has("choices") && obj["choices"].Length > 0) {
            choice := obj["choices"][1]
            if (choice.Has("message")) {
                message := choice["message"]
                chatMsg := ChatMessage("assistant")

                if (message.Has("reasoning")) {
                    chatMsg.AdditionalProperties["thinking"] := message["reasoning"]
                }

                ; Check for tool calls
                if (message.Has("tool_calls") && message["tool_calls"].Length > 0) {
                    for toolCall in message["tool_calls"] {
                        funcCall := FunctionCallContent(
                            toolCall["id"],
                            toolCall["function"]["name"],
                            JSON.Parse(toolCall["function"]["arguments"])
                        )
                        chatMsg.Contents.Push(funcCall)
                    }
                }

                ; Handle regular text response
                if (message.Has("content") && message["content"] != "") {
                    chatMsg.Contents.Push(TextContent(message["content"]))
                }

                ; Add token usage
                if (obj.Has("usage") && obj["usage"].Has("total_tokens")) {
                    chatMsg.AdditionalProperties["tokens"] := obj["usage"]["total_tokens"]
                }

                results.Push(chatMsg)
            }
        }

        if (results.Length > 0) {
            return results
        }

        throw Error(response)
    }

    ReorderToolCallsAndResults(messages) {
        ; Create a map of tool call IDs to their positions
        toolCallPositions := Map()
        reorderedMessages := []

        ; First pass: identify tool calls and build the position map
        loop messages.Length {
            msg := messages[A_Index]

            ; If this is an assistant message with tool calls
            hasFunctionCalls := false
            for part in msg.Contents {
                if (part is FunctionCallContent) {
                    hasFunctionCalls := true
                    toolCallPositions[part.Id] := reorderedMessages.Length + 1
                }
            }

            ; Add all non-tool messages to the result
            if (msg.Role != "tool") {
                reorderedMessages.Push(msg)
            }
        }

        ; Second pass: insert tool results after their corresponding tool calls
        loop messages.Length {
            msg := messages[A_Index]

            ; If this is a tool result message
            if (msg.Role = "tool") {
                toolCallId := ""
                for part in msg.Contents {
                    if (part is FunctionResultContent) {
                        toolCallId := part.CallId
                        break
                    }
                }

                ; If we have a record of the corresponding tool call
                if (toolCallId != "" && toolCallPositions.Has(toolCallId)) {
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

    AdaptMessages(messages) {
        cleanedMessages := []
        for msg in messages {
            ; Convert ChatMessage to plain object and remove additional properties
            ; ToObject(false) (default) now excludes internal properties like duration and tokens
            obj := msg.ToObject()
            cleanedMessages.Push(obj)
        }
        return cleanedMessages
    }
}
