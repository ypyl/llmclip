#Include ..\Services\LLM\Types.ahk

class MessagePresentationService {
    /**
     * Get data for a ListView item representing this message.
     * @param message - ChatMessage instance
     * @returns {Object} {roleEmoji, contentText, duration, tokens}
     */
    static GetListViewItem(message) {
        roleEmoji := MessagePresentationService.GetRoleEmoji(message.Role)

        duration := message.AdditionalProperties.Has("duration") ? message.AdditionalProperties["duration"] : ""
        tokens := message.AdditionalProperties.Has("tokens") ? message.AdditionalProperties["tokens"] : ""

        ; Get presentation text from service, excluding thinking content for the list view
        presentationText := MessagePresentationService.GetPresentationText(message, false)

        ; Get content with truncation for ListView
        contentText := SubStr(presentationText, 1, 70) (StrLen(presentationText) > 70 ? "..." : "")

        return {
            roleEmoji: roleEmoji,
            contentText: contentText,
            duration: duration,
            tokens: tokens
        }
    }

    /**
     * Get the emoji representation for a message role.
     */
    static GetRoleEmoji(role) {
        return role == "system" ? "⚙️" :
               role == "user" ? "👤" :
               role == "assistant" ? "🤖" :
               role == "tool" ? "🛠️" : role
    }

    /**
     * Get the presentation text for a message, considering its role and context.
     * @param message - ChatMessage instance
     * @returns String Markdown/HTML for display
     */
    static GetPresentationText(message, includeThinking := true) {
        if (message.Role == "user" && message.AdditionalProperties.Has("hasContext") && message.AdditionalProperties["hasContext"]) {
            ; For user message with context, show only the user prompt parts
            hasTextContext := message.AdditionalProperties.Has("hasTextContext") && message.AdditionalProperties["hasTextContext"]

            userContent := ""
            for i, part in message.Contents {
                ; Skip Contents[1] only if it is context text (hasTextContext is true)
                if (hasTextContext && i == 1)
                    continue
                ; Skip all ImageContent parts (they belong to the context row)
                if (part is ImageContent)
                    continue
                if (part is TextContent) {
                    if (userContent != "")
                        userContent .= "`n"
                    userContent .= part.Text
                }
            }

            if (userContent == "") {
                userContent := "(empty message)"
            }

            return userContent
        }

        return MessagePresentationService.GetMessageAsString(message, includeThinking)
    }

    /**
     * Converts a ChatMessage to a string representation for display.
     * @param message - ChatMessage instance
     * @param includeThinking - Whether to include thinking/reasoning blocks
     */
    static GetMessageAsString(message, includeThinking := true) {
        ; Check for audio content
        audioData := message.GetAudio()
        if (audioData != "") {
            return MessagePresentationService.FormatAudioMessage(audioData)
        }

        ; Check for tool calls and results
        toolCallTexts := []
        for part in message.Contents {
            if (part is FunctionCallContent) {
                toolCallTexts.Push(MessagePresentationService.FormatToolCallMessage(part))
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

        return text
    }

    /**
     * Get the list-view item for a synthetic context row.
     * @param message - ChatMessage instance that has context
     * @returns {Object} {roleEmoji, contentText, duration, tokens}
     */
    static GetContextListViewItem(message) {
        textCount := 0
        imageCount := 0
        for part in message.Contents {
            if (A_Index == 1)
                continue
            if (part is ImageContent)
                imageCount++
            else if (part is TextContent)
                textCount++
        }

        ; Build label: distinguish text-only, image-only, and mixed
        labelParts := []
        if (textCount > 0)
            labelParts.Push(textCount . " item" . (textCount != 1 ? "s" : ""))
        if (imageCount > 0)
            labelParts.Push("🖼️ " . imageCount . " image" . (imageCount != 1 ? "s" : ""))

        label := ""
        for i, part in labelParts {
            if (i > 1)
                label .= ", "
            label .= part
        }

        return {
            roleEmoji: "📎",
            contentText: label . " attached",
            duration: "",
            tokens: ""
        }
    }

    /**
     * Get the list-view item for a synthetic thinking row.
     * @param message - ChatMessage instance that has thinking content
     * @returns {Object} {roleEmoji, contentText, duration, tokens}
     */
    static GetThinkingListViewItem(message) {
        thinkingContent := message.AdditionalProperties["thinking"]
        contentText := SubStr(thinkingContent, 1, 70) . (StrLen(thinkingContent) > 70 ? "..." : "")
        return {
            roleEmoji: "💭",
            contentText: contentText,
            duration: "",
            tokens: ""
        }
    }

    /**
     * Get presentation text (Markdown) for a synthetic context row.
     * @param message - ChatMessage instance that has context
     * @returns String Markdown for display in the WebView
     */
    static GetContextPresentationText(message) {
        hasTextContext := message.AdditionalProperties.Has("hasTextContext") && message.AdditionalProperties["hasTextContext"]

        result := "**📎 Attached context:**`n`n`n"

        ; 1. Render text context (Contents[1] when hasTextContext is true)
        if (hasTextContext && message.Contents.Length >= 1 && message.Contents[1] is TextContent) {
            result .= message.Contents[1].Text . "`n"
        }

        ; 2. Render images from all ImageContent parts
        hasImages := false
        for part in message.Contents {
            if (!(part is ImageContent))
                continue

            if (!hasImages && hasTextContext) {
                ; Add blank line between text context and images
                result .= "`n"
            }
            hasImages := true

            if (part.Data != "") {
                ; Handle data: URIs (from clipboard) vs raw base64 (from files)
                if (InStr(part.Data, "data:") == 1) {
                    ; Already a full data URI — use directly
                    result .= "![Image](" . part.Data . ")`n"
                } else {
                    mime := part.MimeType != "" ? part.MimeType : "image/png"
                    result .= "![Image](data:" . mime . ";base64," . part.Data . ")`n"
                }
            } else if (part.Url != "") {
                result .= "![Image](" . part.Url . ")`n"
            }
        }

        return result
    }

    /**
     * Get presentation text (Markdown) for a synthetic thinking row.
     * @param message - ChatMessage instance that has thinking content
     * @returns String Markdown for display in the WebView
     */
    static GetThinkingPresentationText(message) {
        thinkingContent := message.AdditionalProperties["thinking"]
        fence := InStr(thinkingContent, "``````") ? "````````" : "``````"
        return fence . "thinking`n" . thinkingContent . "`n" . fence
    }

    static FormatAudioMessage(audioLink) {
        audioBase64 := FileService.GetFileAsBase64(audioLink)
        return '<audio controls><source src="data:audio/wav;base64,' audioBase64 '" type="audio/wav"></audio>'
    }

    static FormatToolCallMessage(toolCall) {
        try {
            result := "**" toolCall.Name "**"
            if (toolCall.Arguments.Count > 0) {
                result .= "`n"
                for key, value in toolCall.Arguments {
                    result .= "- **" key "**:`n" value "`n"
                }
            }
            return result
        } catch {
            return toolCall.Name "(...)"
        }
    }
}
