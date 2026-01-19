#Include ..\..\Lib\Json.ahk
#Include "..\Types.ahk"

class BaseProvider {
    /**
     * Get the request body for the API call
     * @param messages - The history of messages
     * @param settings - The settings object
     * @returns The request body as a Map
     */
    GetRequestBody(messages, settings) {
        throw Error("Not implemented")
    }

    /**
     * Parse the response from the API
     * @param response - The raw response string
     * @returns An array of result objects
     */
    ParseResponse(response) {
        throw Error("Not implemented")
    }

    /**
     * Add token usage information to the result
     * @param obj - The full response object
     * @param result - The result object to add tokens to
     * @returns The modified result object
     */
    AddTokensToResult(obj, result) {
        if (obj.Has("usage") && obj["usage"].Has("total_tokens")) {
            result.tokens := obj["usage"]["total_tokens"]
        }
        return result
    }

    /**
     * Filter out audio messages and their corresponding user prompts
     * @param messages - The list of messages to filter (ChatMessage instances)
     * @returns The filtered list of messages
     */
    FilterMessages(messages) {
        filteredMessages := []
        skipNextUser := false

        ; Process messages in reverse order to identify audio messages first
        i := messages.Length
        loop messages.Length {
            msg := messages[i]

            ; If this is an audio message, skip it and mark to skip the next user message
            if (msg.Role = "assistant" && msg.GetText() = "" && msg.GetAudio() != "") {
                skipNextUser := true
                i--
                continue
            }

            ; Skip the user message that triggered an audio response
            if (skipNextUser && msg.Role = "user") {
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
}
