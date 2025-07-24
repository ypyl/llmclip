#Include <JSON>

class FileSystemTool {
    ReadFile(filePath) {
        try {
            return FileRead(filePath)
        } catch as e {
            return "Error reading file: " e.Message
        }
    }

    WriteFile(filePath, content) {
        try {
            FileAppend(content, filePath)
            return "File written successfully"
        } catch as e {
            return "Error writing file: " e.Message
        }
    }

    DeleteFile(filePath) {
        try {
            FileDelete(filePath)
            return "File deleted successfully"
        } catch as e {
            return "Error deleting file: " e.Message
        }
    }

    GetOpenAiToolDefinition() {
        return {
            type: "function",
            function: {
                name: "file_operation",
                description: "Read from, write to, or delete files on the system",
                parameters: {
                    type: "object",
                    properties: {
                        operation: {
                            type: "string",
                            description: "The operation to perform (read/write/delete)",
                            enum: ["read", "write", "delete"]
                        },
                        path: {
                            type: "string",
                            description: "The full path to the file"
                        },
                        content: {
                            type: "string",
                            description: "The content to write (only for write operation)"
                        }
                    },
                    required: ["operation", "path"]
                }
            }
        }
    }
    GetGeminiToolDefinition() {
        return {
            functionDeclarations: [
                {
                    name: "file_operation",
                    description: "Read from, write to, or delete files on the system",
                    parameters: {
                        type: "object",
                        properties: {
                            operation: {
                                type: "string",
                                description: "The operation to perform (read/write/delete)",
                                enum: ["read", "write", "delete"]
                            },
                            path: {
                                type: "string",
                                description: "The full path to the file"
                            },
                            content: {
                                type: "string",
                                description: "The content to write (only for write operation)"
                            }
                        },
                        required: ["operation", "path"]
                    }
                }
            ]
        }
    }

    ExecuteToolCall(toolCall) {
        if (toolCall.function.name != "file_operation") {
            return
        }

        try {
            args := JSON.parse(toolCall.function.arguments)
            if (!args.Has("operation") || !args.Has("path")) {
                return { role: "tool", content: "Error: Missing required parameters", tool_call_id: toolCall.id }
            }

            if (args["operation"] = "read") {
                result := this.ReadFile(args["path"])
                return { role: "tool", content: result, tool_call_id: toolCall.id }
            }
            else if (args["operation"] = "write") {
                if (!args.Has("content")) {
                    return { role: "tool", content: "Error: Content is required for write operation", tool_call_id: toolCall.id }
                }
                result := this.WriteFile(args["path"], args["content"])
                return { role: "tool", content: result, tool_call_id: toolCall.id }
            }
            else if (args["operation"] = "delete") {
                result := this.DeleteFile(args["path"])
                return { role: "tool", content: result, tool_call_id: toolCall.id }
            }
            return { role: "tool", content: "Error: Invalid operation", tool_call_id: toolCall.id }
        } catch as e {
            return { role: "tool", content: "Error: " e.Message, tool_call_id: toolCall.id }
        }
    }
}
