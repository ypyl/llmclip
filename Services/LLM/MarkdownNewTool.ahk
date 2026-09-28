#Include ..\..\Utils\WebContentFetcher.ahk

class MarkdownNewTool {
    isCancelled := false
    static TOOL_NAME := "read_url_markdown"
    static TOOL_LABEL := "Read URL Markdown"

    /**
     * Execute a web fetch request using markdown.new API via curl
     * @param targetUrl - The URL to fetch
     * @returns The fetched markdown content
     */
    Execute(targetUrl) {
        if (this.isCancelled) {
            return "Operation cancelled by user"
        }

        parsed := WebContentFetcher.ParseMarkdownResponse(WebContentFetcher.FetchMarkdown(targetUrl))
        if (!parsed.ok)
            return parsed.error

        return parsed.raw
    }

    /**
     * Single source of truth for this tool's schema, shared by all providers
     */
    static GetToolSchema() {
        return {
            name: MarkdownNewTool.TOOL_NAME,
            description: "Converts any URL to clean Markdown using Cloudflare's markdown.new service. Use this to read the content of web pages.",
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
        return {type: "function", function: MarkdownNewTool.GetToolSchema()}
    }

    /**
     * Execute a tool call from the LLM
     * @param toolCall - The tool call object from the LLM
     * @returns The tool response message
     */
    ExecuteToolCall(toolCall) {
        if (toolCall.Name != MarkdownNewTool.TOOL_NAME) {
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
            result := this.Execute(args["url"])

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
    }
}
