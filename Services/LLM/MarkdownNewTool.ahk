#Include ..\..\Lib\Json.ahk
#Include ..\..\Utils\TempFileManager.ahk

class MarkdownNewTool {
    currentPid := 0
    isCancelled := false
    static TOOL_NAME := "read_url_markdown"

    /**
     * Execute a web fetch request using markdown.new API via curl
     * @param targetUrl - The URL to fetch
     * @returns The fetched markdown content
     */
    Execute(targetUrl) {
        try {
            ; Check for cancellation
            if (this.isCancelled) {
                return "Operation cancelled by user"
            }

            apiUrl := "https://markdown.new/"

            body := Map()
            body["url"] := targetUrl
            body["method"] := "auto"

            ; Create temporary files for request and response
            requestFile := TempFileManager.GetPath(Format("{1}_{2}", A_TickCount, "request.json"))
            responseFile := TempFileManager.GetPath(Format("{1}_{2}", A_TickCount, "response.json"))

            ; Write request body to temp file
            if FileExist(requestFile)
                FileDelete(requestFile)
            FileAppend(JSON.Dump(body), requestFile)

            ; Prepare curl command
            ; -s: Silent mode
            ; -X POST: POST request
            ; -H: specific headers
            ; -d @file: Read body from file
            ; -o file: Write output to file
            curlCmd := Format('curl.exe -s -X POST "{1}" -H "Content-Type: application/json" -d "@{2}" -o "{3}"', apiUrl, requestFile, responseFile)

            ; Execute curl
            Run(curlCmd, , "Hide", &pid)
            this.currentPid := pid

            ; Wait for process to finish or cancellation
            while (ProcessExist(this.currentPid)) {
                if (this.isCancelled) {
                    ProcessClose(this.currentPid)
                    this.CleanupFiles(requestFile, responseFile)
                    return "Operation cancelled by user"
                }
                Sleep(100)
            }

            this.currentPid := 0

            if (this.isCancelled) {
                this.CleanupFiles(requestFile, responseFile)
                return "Operation cancelled by user"
            }

            ; Check if response file exists and read it
            if (FileExist(responseFile)) {
                response := FileRead(responseFile, "UTF-8")
                this.CleanupFiles(requestFile, responseFile)

                if (response == "") {
                    return "Error: Empty response received from markdown.new"
                }

                ; Check if response is JSON (error) or Markdown
                ; markdown.new returns JSON on error sometimes, but usually 200 OK with markdown
                ; If it starts with { and ends with }, it might be a JSON error message
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
            } else {
                this.CleanupFiles(requestFile, responseFile)
                return "Error: Failed to fetch content (no response file)"
            }

        } catch as e {
            return "Error executing markdown fetch: " . e.Message
        }
    }

    CleanupFiles(requestFile, responseFile) {
        try {
            if (FileExist(requestFile))
                FileDelete(requestFile)
            if (FileExist(responseFile))
                FileDelete(responseFile)
        }
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
