#Include ..\..\Lib\Json.ahk

class WebFetchTool {
    currentHttpObject := ""
    isCancelled := false

    /**
     * Execute a web fetch request using Ollama API
     * @param targetUrl - The URL to fetch
     * @param apiKey - The Ollama API key
     * @returns The fetched content
     */
    Execute(targetUrl, apiKey := "") {
        try {
            ; Check for cancellation
            if (this.isCancelled) {
                return "Operation cancelled by user"
            }

            apiUrl := "https://ollama.com/api/web_fetch"

            body := Map()
            body["url"] := targetUrl

            http := ComObject("WinHttp.WinHttpRequest.5.1")
            this.currentHttpObject := http
            http.Open("POST", apiUrl, true)
            http.SetRequestHeader("Content-Type", "application/json")
            if (apiKey != "")
                http.SetRequestHeader("Authorization", "Bearer " . apiKey)

            http.Send(JSON.Dump(body))

            ; Wait for response with cancellation check
            while (!http.WaitForResponse(100)) {
                ; Check for cancellation every 100ms
                if (this.isCancelled) {
                    try http.Abort()
                    this.currentHttpObject := ""
                    return "Operation cancelled by user"
                }
            }

            this.currentHttpObject := ""

            if (http.Status != 200) {
                return "Error: Web fetch failed with status " . http.Status . " - " . http.ResponseText
            }

            response := JSON.Load(http.ResponseText)

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

        } catch as e {
            return "Error executing web fetch: " . e.Message
        }
    }

    /**
     * Get the OpenAI tool definition for this tool
     */
    static GetOpenAiToolDefinition() {
        return {
            type: "function",
            function: {
                name: "web_fetch",
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
    }

    /**
     * Get the Gemini tool definition for this tool
     */
    static GetGeminiToolDefinition() {
        return {
            functionDeclarations: [{
                name: "web_fetch",
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
            }]
        }
    }

    /**
     * Execute a tool call from the LLM
     * @param toolCall - The tool call object from the LLM
     * @param apiKey - The Ollama API key
     * @returns The tool response message
     */
    ExecuteToolCall(toolCall, apiKey) {
        if (toolCall.Name != "web_fetch") {
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

    /**
     * Cancel any running web request
     */
    Cancel() {
        this.isCancelled := true
        if (this.currentHttpObject != "") {
            try this.currentHttpObject.Abort()
            this.currentHttpObject := ""
        }
    }
}
