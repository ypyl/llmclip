#Include "BaseProvider.ahk"
#Include "..\PowerShellTool.ahk"

class GoogleProvider extends BaseProvider {
    powerShellTool := PowerShellTool()

    GetRequestBody(messages, settings) {
        body := Map()
        contents := []
        systemMessage := ""

        ; Filter messages to remove audio messages and their prompts
        filteredMessages := this.FilterMessages(messages)

        ; First, find and handle system message
        for msg in filteredMessages {
            if (msg.Role = "system") {
                systemMessage := msg
                break
            }
        }

        ; Add system instruction if present
        if (systemMessage) {
            body["system_instruction"] := {
                parts: [{
                    text: systemMessage.GetText()
                }]
            }
        }

        ; Add other messages to contents
        for i, msg in filteredMessages {
            if (msg.Role == "system") {
                continue ; Skip system messages, already handled
            }
            if (msg.Role = "tool") {
                ; Group all tool responses that belong to the same assistant message
                if (i < filteredMessages.Length) {
                    if (filteredMessages[i + 1].Role = "tool") {
                        continue ; Skip this one, we'll handle it in the next pass
                    }
                }

                ; Collect all tool responses that belong to the previous assistant message
                toolResponses := []
                currentIndex := i

                ; Work backwards to collect all tool responses for this group
                while (currentIndex > 0) {
                    currentMsg := filteredMessages[currentIndex]
                    if (currentMsg.Role != "tool")
                        break
                        
                    ; Find FunctionResultContent in the message
                    for part in currentMsg.Contents {
                        if (part is FunctionResultContent) {
                            toolResponses.InsertAt(1, {
                                functionResponse: {
                                    id: part.CallId,
                                    name: "execute_command",
                                    response: { result: part.Result }
                                }
                            })
                            break
                        }
                    }
                    currentIndex--
                }

                ; Add all tool responses as parts of a single user message
                if (toolResponses.Length > 0) {
                    contents.Push({
                        role: "user",
                        parts: toolResponses
                    })
                }
            } else if (msg.Role = "assistant") {
                ; Check if message has function calls
                hasFunctionCalls := false
                for part in msg.Contents {
                    if (part is FunctionCallContent) {
                        hasFunctionCalls := true
                        break
                    }
                }
                
                if (msg.GetText() = "" && hasFunctionCalls) {
                    ; Skip if this is not the last of consecutive assistant messages with tool calls
                    if (i < filteredMessages.Length) {
                        nextMsg := filteredMessages[i + 1]
                        nextHasFunctionCalls := false
                        for part in nextMsg.Contents {
                            if (part is FunctionCallContent) {
                                nextHasFunctionCalls := true
                                break
                            }
                        }
                        if (nextMsg.Role = "assistant" && nextMsg.GetText() = "" && nextHasFunctionCalls) {
                            continue
                        }
                    }

                    ; Collect all function calls from consecutive assistant messages
                    functionCalls := []
                    currentIndex := i

                    ; Work backwards to collect all tool calls from consecutive assistant messages
                    while (currentIndex > 0) {
                        currentMsg := filteredMessages[currentIndex]
                        currentHasFunctionCalls := false
                        for part in currentMsg.Contents {
                            if (part is FunctionCallContent) {
                                currentHasFunctionCalls := true
                                break
                            }
                        }
                        
                        if (currentMsg.Role != "assistant" || currentMsg.GetText() != "" || !currentHasFunctionCalls)
                            break

                        ; Add all function calls from this message
                        for part in currentMsg.Contents {
                            if (part is FunctionCallContent) {
                                functionCalls.InsertAt(1, {
                                    functionCall: {
                                        id: part.Id,
                                        name: part.Name,
                                        args: part.Arguments,
                                    }
                                })
                            }
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
                            text: msg.GetText()
                        }]
                    })
                }
            } else if (msg.Role = "user") {
                ; Only add user messages that aren't immediately after tool messages
                if (i > 1) {
                    if (filteredMessages[i - 1].Role = "tool")
                        continue
                }
                
                contents.Push({
                    role: msg.Role,
                    parts: [{
                        text: msg.GetText()
                    }]
                })
            }
        }

        body["contents"] := contents
        enabledTools := []
        for t in settings.Get("tools", []) {
            if (t = "powerShellTool")
                enabledTools.Push(this.powerShellTool.GetGeminiToolDefinition())
        }
        if (enabledTools.Length > 0)
            body["tools"] := enabledTools
        body["generationConfig"] := {
            stopSequences: settings.Get("stopSequences", ["Title"]),
            temperature: settings.Get("temperature", 1.0),
            maxOutputTokens: settings.Get("maxOutputTokens", 800),
            topP: settings.Get("topP", 0.8),
            topK: settings.Get("topK", 10)
        }
        return body
    }

    ParseResponse(response) {
        obj := JSON.Load(response)
        results := []

        if (obj.Has("candidates") && obj["candidates"].Length > 0) {
            candidate := obj["candidates"][1]
            if (candidate.Has("content") && candidate["content"].Has("parts") && candidate["content"]["parts"].Length > 0) {
                chatMsg := ChatMessage("assistant")
                parts := candidate["content"]["parts"]
                
                for part in parts {
                    if (part.Has("functionCall")) {
                        functionCall := part["functionCall"]
                        funcCall := FunctionCallContent(
                            functionCall.Get("id", ""),
                            functionCall["name"],
                            functionCall["args"]
                        )
                        chatMsg.Contents.Push(funcCall)
                    } else if (part.Has("text")) {
                        chatMsg.Contents.Push(TextContent(part["text"]))
                    }
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
}
