#Requires AutoHotkey 2.0
#Include ..\..\Lib\Json.ahk
#Include ..\Configuration\ConfigurationService.ahk

class PromptCreatorTool {
    static TOOL_NAME := "create_prompt"

    /**
     * Sanitize a display name to a safe kebab-case filename.
     * Converts to lowercase, replaces non-alphanumeric with hyphens,
     * collapses consecutive hyphens, and trims leading/trailing hyphens.
     * @param name - The display name to sanitize
     * @returns Sanitized filename (without extension)
     */
    static SanitizeFileName(name) {
        sanitized := StrLower(name)
        ; Replace any character that is not a-z, 0-9, or hyphen with a hyphen
        sanitized := RegExReplace(sanitized, "[^a-z0-9\-]", "-")
        ; Collapse multiple consecutive hyphens
        sanitized := RegExReplace(sanitized, "-{2,}", "-")
        ; Trim leading and trailing hyphens
        sanitized := RegExReplace(sanitized, "^-+", "")
        sanitized := RegExReplace(sanitized, "-+$", "")
        return sanitized
    }

    /**
     * Get the OpenAI tool definition for this tool
     */
    static GetOpenAiToolDefinition() {
        return {
            type: "function",
            function: {
                name: PromptCreatorTool.TOOL_NAME,
                description: "Create a new system prompt and save it. The prompt defines how the AI behaves (its role, style, constraints). Use this when the user asks you to create, save, or remember a new prompt, role, or personality.",
                parameters: {
                    type: "object",
                    properties: {
                        name: {
                            type: "string",
                            description: "A short display name for the prompt (e.g. 'Rust Code Review', 'Casual Mail')"
                        },
                        value: {
                            type: "string",
                            description: "The system prompt text — instructions that define the AI's behavior, role, style, and constraints. Write this in second person ('You are a...')."
                        },
                        input_template: {
                            type: "string",
                            description: "Optional template for user input, with {placeholders} that get filled in (e.g. 'The repository is at {repo_path}')"
                        },
                        hidden: {
                            type: "boolean",
                            description: "Optional. If true, the prompt won't appear in the prompts menu. Default: false"
                        }
                    },
                    required: ["name", "value"]
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
                name: PromptCreatorTool.TOOL_NAME,
                description: "Create a new system prompt and save it. The prompt defines how the AI behaves (its role, style, constraints). Use this when the user asks you to create, save, or remember a new prompt, role, or personality.",
                parameters: {
                    type: "object",
                    properties: {
                        name: {
                            type: "string",
                            description: "A short display name for the prompt (e.g. 'Rust Code Review', 'Casual Mail')"
                        },
                        value: {
                            type: "string",
                            description: "The system prompt text — instructions that define the AI's behavior, role, style, and constraints. Write this in second person ('You are a...')."
                        },
                        input_template: {
                            type: "string",
                            description: "Optional template for user input, with {placeholders} that get filled in (e.g. 'The repository is at {repo_path}')"
                        },
                        hidden: {
                            type: "boolean",
                            description: "Optional. If true, the prompt won't appear in the prompts menu. Default: false"
                        }
                    },
                    required: ["name", "value"]
                }
            }]
        }
    }

    /**
     * Execute a tool call from the LLM
     * @param toolCall - The tool call object from the LLM
     * @returns The tool response ChatMessage
     */
    ExecuteToolCall(toolCall) {
        if (toolCall.Name != PromptCreatorTool.TOOL_NAME) {
            return
        }

        try {
            args := toolCall.Arguments

            ; Validate required parameters
            if (!args.Has("name")) {
                msg := ChatMessage("tool")
                msg.Contents.Push(FunctionResultContent(toolCall.Id, "Error: Missing required parameter 'name'"))
                return msg
            }
            if (!args.Has("value")) {
                msg := ChatMessage("tool")
                msg.Contents.Push(FunctionResultContent(toolCall.Id, "Error: Missing required parameter 'value'"))
                return msg
            }

            displayName := args["name"]
            valueText := args["value"]
            inputTemplate := args.Has("input_template") ? args["input_template"] : ""
            hidden := args.Has("hidden") ? args["hidden"] : false

            ; Sanitize display name to safe filename
            sanitizedName := PromptCreatorTool.SanitizeFileName(displayName)
            if (sanitizedName == "") {
                msg := ChatMessage("tool")
                msg.Contents.Push(FunctionResultContent(toolCall.Id, "Error: Prompt name results in an empty filename after sanitization. Please use a name with at least one letter or number."))
                return msg
            }

            ; Check for existing files
            promptsDir := "prompts"
            jsonPath := promptsDir . "\" . sanitizedName . ".json"
            mdPath := promptsDir . "\" . sanitizedName . ".md"

            if (FileExist(jsonPath)) {
                msg := ChatMessage("tool")
                msg.Contents.Push(FunctionResultContent(toolCall.Id, "Error: A prompt with the name '" . displayName . "' already exists (file: " . jsonPath . "). Choose a different name."))
                return msg
            }

            ; Ensure prompts directory exists
            if (!DirExist(promptsDir)) {
                DirCreate(promptsDir)
            }

            ; Build the JSON metadata object
            promptEntry := Map()
            promptEntry["value"] := ".\" . sanitizedName . ".md"

            if (inputTemplate != "") {
                promptEntry["input_template"] := inputTemplate
            }
            if (hidden) {
                promptEntry["hidden"] := true
            }

            promptJson := Map()
            promptJson[displayName] := promptEntry

            ; Write the .md file (system prompt text)
            try {
                if (FileExist(mdPath)) {
                    FileDelete(mdPath)
                }
                FileAppend(valueText, mdPath, "UTF-8-RAW")
            } catch as e {
                msg := ChatMessage("tool")
                msg.Contents.Push(FunctionResultContent(toolCall.Id, "Error writing prompt file: " . e.Message))
                return msg
            }

            ; Write the .json file (metadata)
            try {
                JSON.DumpFile(promptJson, jsonPath, 2, "UTF-8")
            } catch as e {
                ; Clean up the .md file if .json write fails
                try {
                    if (FileExist(mdPath))
                        FileDelete(mdPath)
                }
                msg := ChatMessage("tool")
                msg.Contents.Push(FunctionResultContent(toolCall.Id, "Error writing prompt metadata: " . e.Message))
                return msg
            }

            ; Reload configuration so the new prompt appears in the UI
            try {
                ConfigurationService.GetInstance().Reload()
            } catch as e {
                ; Reload failure is non-fatal — the files are already written
            }

            msg := ChatMessage("tool")
            msg.Contents.Push(FunctionResultContent(toolCall.Id, "Successfully created system prompt '" . displayName . "' (saved to " . jsonPath . " and " . mdPath . "). The prompt is now available in the prompts menu."))
            return msg

        } catch as e {
            msg := ChatMessage("tool")
            msg.Contents.Push(FunctionResultContent(toolCall.Id, "Error: " . e.Message))
            return msg
        }
    }
}
