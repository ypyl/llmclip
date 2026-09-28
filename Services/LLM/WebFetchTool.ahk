#Include OllamaHttpTool.ahk

class WebFetchTool extends OllamaHttpTool {
    static TOOL_NAME := "web_fetch"
    static TOOL_LABEL := "Web Fetch"

    /**
     * Execute a web fetch request using Ollama API
     * @param targetUrl - The URL to fetch
     * @param apiKey - The Ollama API key
     * @returns The fetched content
     */
    Execute(targetUrl, apiKey := "") {
        apiUrl := "https://ollama.com/api/web_fetch"

        body := Map()
        body["url"] := targetUrl

        result := this.PostJson(apiUrl, body, apiKey, "Web fetch")
        if (!result.ok)
            return result.error

        response := result.response

        resultText := "Fetch Results for '" . targetUrl . "':`n`n"

        title := response.Has("title") ? response["title"] : "No Title"
        content := response.Has("content") ? response["content"] : ""

        resultText .= "Title: " . title . "`n"
        if (content != "")
            resultText .= "Content: " . content . "`n"

        if (response.Has("links") && response["links"] is Array) {
            resultText .= "`nValuable Links:`n"
            count := 0
            for link in response["links"] {
                if (count >= 10) ; Limit links display
                    break
                resultText .= "- " . link . "`n"
                count++
            }
        }

        return resultText
    }

    /**
     * Single source of truth for this tool's schema, shared by all providers
     */
    static GetToolSchema() {
        return {
            name: WebFetchTool.TOOL_NAME,
            description: "Fetches a single web page by URL and returns its content. Use this to read the content of a specific page.",
            parameters: {
                type: "object",
                properties: {
                    url: {
                        type: "string",
                        description: "The URL of the web page to fetch"
                    }
                },
                required: ["url"]
            }
        }
    }

    /**
     * Get the OpenAI tool definition for this tool
     */
    GetOpenAiToolDefinition() {
        return {type: "function", function: WebFetchTool.GetToolSchema()}
    }

    /**
     * Execute a tool call from the LLM
     * @param toolCall - The tool call object from the LLM
     * @param apiKey - The Ollama API key
     * @returns The tool response message
     */
    ExecuteToolCall(toolCall, apiKey) {
        if (toolCall.Name != WebFetchTool.TOOL_NAME) {
            return
        }

        try {
            args := toolCall.Arguments

            if (!args.Has("url")) {
                msg := ChatMessage("tool")
                msg.Contents.Push(FunctionResultContent(toolCall.Id, "Error: Missing required parameter 'url'"))
                return msg
            }

            ; Execute the web fetch with cancellation support
            result := this.Execute(args["url"], apiKey)

            msg := ChatMessage("tool")
            msg.Contents.Push(FunctionResultContent(toolCall.Id, result))
            return msg

        } catch as e {
            msg := ChatMessage("tool")
            msg.Contents.Push(FunctionResultContent(toolCall.Id, "Error: " . e.Message))
            return msg
        }
    }
}
