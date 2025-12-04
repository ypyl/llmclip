#Requires AutoHotkey 2.0

/**
 * Represents the role of a chat message author.
 */
class ChatRole {
    static User => "user"
    static Assistant => "assistant"
    static System => "system"
    static Tool => "tool"

    __New(role) {
        this.Value := role
    }

    ToString() {
        return this.Value
    }
}

/**
 * Base class for content parts of a chat message.
 */
class ChatContent {
    Type := ""
}

class TextContent extends ChatContent {
    Text := ""

    __New(text) {
        this.Type := "text"
        this.Text := text
    }
}

class ImageContent extends ChatContent {
    Url := ""
    Data := "" ; Base64 data
    MimeType := ""

    __New(urlOrData, mimeType := "") {
        this.Type := "image_url"
        if (InStr(urlOrData, "http") == 1) {
            this.Url := urlOrData
        } else {
            this.Data := urlOrData
        }
        this.MimeType := mimeType
    }
}

class AudioContent extends ChatContent {
    Data := "" ; Base64 data or path
    Format := ""

    __New(dataOrPath, format := "wav") {
        this.Type := "audio"
        this.Data := dataOrPath
        this.Format := format
    }
}

class FunctionCallContent extends ChatContent {
    Id := ""
    Name := ""
    Arguments := Map()

    __New(id, name, arguments) {
        this.Type := "function_call"
        this.Id := id
        this.Name := name
        this.Arguments := arguments
    }
}

class FunctionResultContent extends ChatContent {
    CallId := ""
    Result := ""

    __New(callId, result) {
        this.Type := "function_result"
        this.CallId := callId
        this.Result := result
    }
}

/**
 * Represents a chat message.
 */
class ChatMessage {
    Role := "" ; ChatRole
    Contents := [] ; Array of ChatContent
    AuthorName := ""
    AdditionalProperties := Map()

    __New(role, content := "") {
        this.Role := role
        if (content != "") {
            if (IsObject(content) && HasProp(content, "__Class") && (content is ChatContent)) {
                this.Contents.Push(content)
            } else if (Type(content) == "String") {
                this.Contents.Push(TextContent(content))
            } else if (Type(content) == "Array") {
                this.Contents := content
            }
        }
    }

    AddText(text) {
        this.Contents.Push(TextContent(text))
    }

    AddImage(urlOrData, mimeType := "") {
        this.Contents.Push(ImageContent(urlOrData, mimeType))
    }

    /**
     * Get text content from the message
     * @returns Combined text from all TextContent parts
     */
    GetText() {
        text := ""
        for part in this.Contents {
            if (part is TextContent)
                text .= part.Text
        }
        return text
    }

    GetAudio() {
        for part in this.Contents {
            if (part is AudioContent)
                return part.Data
        }
        return ""
    }

    /**
     * Convert ChatMessage to plain object for API calls or serialization
     * @returns Plain object representation
     */
    ToObject() {
        obj := {}
        obj.role := this.Role

        ; Handle content based on what's in Contents array
        if (this.Contents.Length == 0) {
            obj.content := ""
        } else if (this.Contents.Length == 1 && (this.Contents[1] is TextContent)) {
            ; Simple text content
            obj.content := this.Contents[1].Text
        } else {
            ; Multipart content (images, etc.)
            obj.content := []
            for part in this.Contents {
                if (part is TextContent) {
                    obj.content.Push({type: "text", text: part.Text})
                } else if (part is ImageContent) {
                    imageObj := {type: "image_url"}
                    if (part.Url != "") {
                        imageObj.image_url := {url: part.Url}
                    } else if (part.Data != "") {
                        ; Construct data URI
                        mimeType := part.MimeType != "" ? part.MimeType : "image/jpeg"
                        imageObj.image_url := {url: "data:" . mimeType . ";base64," . part.Data}
                    }
                    obj.content.Push(imageObj)
                } else if (part is AudioContent) {
                    obj.audio := {link: part.Data, format: part.Format}
                } else if (part is FunctionCallContent) {
                    if (!obj.HasOwnProp("tool_calls"))
                        obj.tool_calls := []
                    obj.tool_calls.Push({
                        id: part.Id,
                        type: "function",
                        function: {
                            name: part.Name,
                            arguments: JSON.Stringify(part.Arguments)
                        }
                    })
                } else if (part is FunctionResultContent) {
                    obj.role := "tool"
                    obj.tool_call_id := part.CallId
                    obj.content := part.Result
                }
            }
        }

        ; Copy additional properties
        for key, value in this.AdditionalProperties {
            obj.%key% := value
        }

        return obj
    }

    /**
     * Create ChatMessage from plain object (deserialization)
     * @param obj - Plain object from JSON or API
     * @returns ChatMessage instance
     */
    static FromObject(obj) {
        ; Determine role
        role := obj.HasOwnProp("role") ? obj.role : "user"

        msg := ChatMessage(role)

        ; Handle content
        if (obj.HasOwnProp("content")) {
            content := obj.content
            if (Type(content) == "String") {
                if (content != "")
                    msg.Contents.Push(TextContent(content))
            } else if (Type(content) == "Array") {
                ; Multipart content
                for part in content {
                    if (part.HasOwnProp("type")) {
                        if (part.type == "text") {
                            msg.Contents.Push(TextContent(part.text))
                        } else if (part.type == "image_url") {
                            imageUrl := part.image_url.url
                            ; Check if it's a data URI
                            if (InStr(imageUrl, "data:") == 1) {
                                ; Extract mime type and base64 data
                                commaPos := InStr(imageUrl, ",")
                                if (commaPos > 0) {
                                    header := SubStr(imageUrl, 1, commaPos - 1)
                                    base64Data := SubStr(imageUrl, commaPos + 1)
                                    ; Extract mime type from header (data:image/jpeg;base64)
                                    mimeType := ""
                                    if (RegExMatch(header, "data:([^;]+)", &match))
                                        mimeType := match[1]
                                    msg.Contents.Push(ImageContent(base64Data, mimeType))
                                }
                            } else {
                                msg.Contents.Push(ImageContent(imageUrl))
                            }
                        }
                    }
                }
            }
        }

        ; Handle audio
        if (obj.HasOwnProp("audio")) {
            audioData := obj.audio.HasOwnProp("link") ? obj.audio.link : ""
            audioFormat := obj.audio.HasOwnProp("format") ? obj.audio.format : "wav"
            msg.Contents.Push(AudioContent(audioData, audioFormat))
        }

        ; Handle tool calls
        if (obj.HasOwnProp("tool_calls")) {
            for toolCall in obj.tool_calls {
                funcCall := FunctionCallContent(
                    toolCall.id,
                    toolCall.function.name,
                    JSON.Parse(toolCall.function.arguments)
                )
                msg.Contents.Push(funcCall)
            }
        }

        ; Handle tool results
        if (obj.HasOwnProp("tool_call_id")) {
            result := obj.HasOwnProp("content") ? obj.content : ""
            msg.Contents.Push(FunctionResultContent(obj.tool_call_id, result))
        }

        ; Store additional properties (duration, tokens, thinking, etc.)
        for key in ["duration", "tokens", "thinking"] {
            if (obj.HasOwnProp(key)) {
                msg.AdditionalProperties[key] := obj.%key%
            }
        }

        return msg
    }
}

/**
 * Configuration options for chat requests.
 */
class ChatOptions {
    Model := ""
    Temperature := 0.7
    MaxOutputTokens := 800
    TopP := 0.8
    TopK := 10
    StopSequences := []
    Tools := []
    ResponseFormat := "text" ; text, json_object, audio
    Voice := "" ; For audio generation

    __New(model := "") {
        this.Model := model
    }
}

/**
 * Represents token usage information.
 */
class UsageDetails {
    InputTokens := 0
    OutputTokens := 0
    TotalTokens := 0

    __New(input := 0, output := 0, total := 0) {
        this.InputTokens := input
        this.OutputTokens := output
        this.TotalTokens := total
    }
}

/**
 * Represents a single choice in a chat response.
 */
class ChatChoice {
    Message := "" ; ChatMessage
    FinishReason := ""
    Index := 0

    __New(message, finishReason := "", index := 0) {
        this.Message := message
        this.FinishReason := finishReason
        this.Index := index
    }
}

/**
 * Represents the response from a chat completion request.
 */
class ChatResponse {
    Choices := [] ; Array of ChatChoice
    Usage := "" ; UsageDetails
    RawResponse := ""

    __New(choices := [], usage := "", rawResponse := "") {
        this.Choices := choices
        this.Usage := usage ? usage : UsageDetails()
        this.RawResponse := rawResponse
    }

    FirstChoice {
        get {
            if (this.Choices.Length > 0)
                return this.Choices[1]
            return ""
        }
    }

    Text {
        get {
            if (this.FirstChoice && this.FirstChoice.Message && this.FirstChoice.Message.Contents.Length > 0) {
                text := ""
                for part in this.FirstChoice.Message.Contents {
                    if (part is TextContent)
                        text .= part.Text
                }
                return text
            }
            return ""
        }
    }
}
