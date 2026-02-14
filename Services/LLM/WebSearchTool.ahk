#Include ..\..\Lib\Json.ahk

class WebSearchTool {
    currentHttpObject := ""
    isCancelled := false

    /**
     * Execute a web search query using Ollama API
     * @param query - The search query
     * @param max_results - Maximum number of results to return
     * @param apiKey - The Ollama API key
     * @returns The search results
     */
    Execute(query, max_results := 5, apiKey := "") {
        try {
            ; Check for cancellation
            if (this.isCancelled) {
                return "Operation cancelled by user"
            }

            url := "https://ollama.com/api/web_search"

            body := Map()
            body["query"] := query
            if (max_results)
                body["max_results"] := max_results

            http := ComObject("WinHttp.WinHttpRequest.5.1")
            this.currentHttpObject := http
            http.Open("POST", url, true)
            http.SetRequestHeader("Content-Type", "application/json")
            if (apiKey != "")
                http.SetRequestHeader("Authorization", "Bearer " . apiKey)

            http.Send(JSON.Dump(body))

            ; Wait for response with cancellation check
            startTime := A_TickCount
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
                return "Error: Web search failed with status " . http.Status . " - " . http.ResponseText
            }

            response := JSON.Load(http.ResponseText)

            resultText := "Search Results for '" . query . "':`n`n"

            if (response.Has("results") && response["results"] is Array) {
                for item in response["results"] {
                    title := item.Has("title") ? item["title"] : "No Title"
                    link := item.Has("url") ? item["url"] : "No URL"
                    content := item.Has("content") ? item["content"] : ""

                    resultText .= "Title: " . title . "`n"
                    resultText .= "URL: " . link . "`n"
                    if (content != "")
                        resultText .= "Content: " . content . "`n"
                    resultText .= "`n-------------------`n"
                }
            } else {
                resultText .= "No results found."
            }

            return resultText

        } catch as e {
            return "Error executing web search: " . e.Message
        }
    }

    /**
     * Get the OpenAI tool definition for this tool
     */
    static GetOpenAiToolDefinition() {
        return {
            type: "function",
            function: {
                name: "web_search",
                description: "Performs a web search for a single query and returns relevant results. Use this to get latest information.",
                parameters: {
                    type: "object",
                    properties: {
                        query: {
                            type: "string",
                            description: "The search query string"
                        },
                        max_results: {
                            type: "integer",
                            description: "Maximum results to return (default 5, max 10)"
                        }
                    },
                    required: ["query"]
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
                name: "web_search",
                description: "Performs a web search for a single query and returns relevant results. Use this to get latest information.",
                parameters: {
                    type: "object",
                    properties: {
                        query: {
                            type: "string",
                            description: "The search query string"
                        },
                        max_results: {
                            type: "integer",
                            description: "Maximum results to return (default 5, max 10)"
                        }
                    },
                    required: ["query"]
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
        if (toolCall.Name != "web_search") {
            return
        }

        try {
            args := toolCall.Arguments

            if (!args.Has("query")) {
                msg := ChatMessage("tool")
                msg.Contents.Push(FunctionResultContent(toolCall.Id, "Error: Missing required parameter 'query'"))
                return msg
            }

            max_results := args.Has("max_results") ? args["max_results"] : 5

            ; Execute the web search with cancellation support
            result := this.Execute(args["query"], max_results, apiKey)

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
