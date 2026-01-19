#Include "BaseProvider.ahk"

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

            ollamaMessages.Push(newMsg)
        }

        body["messages"] := ollamaMessages
        return body
    }

    ParseResponse(response) {
        obj := JSON.Load(response)
        results := []

        ; Handle format with direct message object (Ollama often returns this)
        if (obj.Has("message") && obj["message"].Has("content")) {
            msgObj := obj["message"]
            chatMsg := ChatMessage("assistant", [TextContent(msgObj["content"])])
            
            if (msgObj.Has("thinking")) {
                chatMsg.AdditionalProperties["thinking"] := msgObj["thinking"]
            }
            
            ; Add token usage
            if (obj.Has("usage") && obj["usage"].Has("total_tokens")) {
                chatMsg.AdditionalProperties["tokens"] := obj["usage"]["total_tokens"]
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
