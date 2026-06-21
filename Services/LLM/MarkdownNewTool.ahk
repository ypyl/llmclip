#Include ..\..\Lib\Json.ahk
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

        response := WebContentFetcher.FetchMarkdown(targetUrl)

        ; Check if response is JSON (error) or Markdown
        trimmed := Trim(response, " `t`n`r")
        if (SubStr(trimmed, 1, 1) == "{" && SubStr(trimmed, -1) == "}") {
            try {
                jsonObj := JSON.Load(trimmed)
                if (jsonObj.Has("success") && jsonObj["success"] == 0) {
                     return "Error from markdown.new: " . (jsonObj.Has("message") ? jsonObj["message"] : "Unknown error")
                }
            } catch {
                ; Not valid JSON, proceed as Markdown
            }
        }

        return response
    }

    /**
     * Get the OpenAI tool definition for this tool
     */
    static GetOpenAiToolDefinition() {
        return {
            type: "function",
            function: {
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
    }

    /**
     * Get the Gemini tool definition for this tool
     */
    static GetGeminiToolDefinition() {
        return {
            functionDeclarations: [{
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
            }]
        }
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
