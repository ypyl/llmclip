#Include OllamaHttpTool.ahk

class WebSearchTool extends OllamaHttpTool {
    static TOOL_NAME := "web_search"
    static TOOL_LABEL := "Web Search"

    /**
     * Execute a web search query using Ollama API
     * @param query - The search query
     * @param max_results - Maximum number of results to return
     * @param apiKey - The Ollama API key
     * @returns The search results
     */
    Execute(query, max_results := 5, apiKey := "") {
        url := "https://ollama.com/api/web_search"

        body := Map()
        body["query"] := query
        if (max_results)
            body["max_results"] := max_results

        result := this.PostJson(url, body, apiKey, "Web search")
        if (!result.ok)
            return result.error

        response := result.response

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
    }

    /**
     * Single source of truth for this tool's schema, shared by all providers
     */
    static GetToolSchema() {
        return {
            name: WebSearchTool.TOOL_NAME,
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

    /**
     * Get the OpenAI tool definition for this tool
     */
    GetOpenAiToolDefinition() {
        return {type: "function", function: WebSearchTool.GetToolSchema()}
    }

    /**
     * Execute a tool call from the LLM
     * @param toolCall - The tool call object from the LLM
     * @param apiKey - The Ollama API key
     * @returns The tool response message
     */
    ExecuteToolCall(toolCall, apiKey) {
        if (toolCall.Name != WebSearchTool.TOOL_NAME) {
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
}
