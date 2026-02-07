#Include FileUtils.ahk
#Include LLM\Types.ahk

class MessagePresentationService {
    /**
     * Get the presentation text for a message, considering its role and context.
     * @param message - ChatMessage instance
     * @returns String Markdown/HTML for display
     */
    GetPresentationText(message, includeThinking := true) {
        if (message.Role == "user" && message.AdditionalProperties.Has("hasContext") && message.AdditionalProperties["hasContext"]) {
            ; For user message with context, show only the user prompt parts
            userContent := ""
            for i, part in message.Contents {
                if (i > 1 && part is TextContent) {
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
            
            return hasImage ? userContent . " [Image]" : userContent
        }

        return this.GetMessageAsString(message, includeThinking)
    }

    /**
     * Converts a ChatMessage to a string representation for display.
     * @param message - ChatMessage instance
     * @param includeThinking - Whether to include thinking/reasoning blocks
     */
    GetMessageAsString(message, includeThinking := true) {
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
        if (includeThinking && message.AdditionalProperties.Has("thinking") && message.AdditionalProperties["thinking"] != "") {
            ; Use 4 backticks for fence if content contains 3 backticks
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
        ; JSON might not be available here directly, but we assume it's global or included via LLM\Types.ahk
        return toolCall.Name "(" JSON.Stringify(toolCall.Arguments) ")"
    }
}
