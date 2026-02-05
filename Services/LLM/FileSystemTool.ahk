#Include ..\..\Lib\Json.ahk

class FileSystemTool {
    /**
     * Read content from a file
     * @param path - The path to the file
     * @returns The content of the file
     */
    static ReadFile(path) {
        try {
            if (!FileExist(path)) {
                return "Error: File not found: " . path
            }
            return FileRead(path, "UTF-8")
        } catch as e {
            return "Error reading file: " . e.Message
        }
    }

    /**
     * Write content to a file
     * @param path - The path to the file
     * @param content - The content to write
     * @param append - Whether to append to the file (default: false)
     * @returns Success message or error
     */
    static WriteFile(path, content, append := false) {
        try {
            ; Create directory if it doesn't exist
            SplitPath(path, , &dir)
            if (dir != "" && !DirExist(dir)) {
                DirCreate(dir)
            }

            if (append) {
                FileAppend(content, path, "UTF-8")
            } else {
                if (FileExist(path)) {
                    FileDelete(path)
                }
                FileAppend(content, path, "UTF-8")
            }
            return "File written successfully: " . path
        } catch as e {
            return "Error writing file: " . e.Message
        }
    }

    /**
     * List files in a directory
     * @param path - The path to the directory
     * @returns List of files and directories
     */
    static ListDir(path) {
        try {
            if (!DirExist(path)) {
                return "Error: Directory not found: " . path
            }

            files := []
            Loop Files, path . "\*", "FD" {
                 info := A_LoopFileName . (InStr(FileExist(A_LoopFileFullPath), "D") ? "/" : "")
                 files.Push(info)
            }
            
            if (files.Length == 0) {
                return "Directory is empty: " . path
            }

            return JSON.Dump(files)
        } catch as e {
             return "Error listing directory: " . e.Message
        }
    }


    /**
     * Get the OpenAI tool definition for this tool
     */
    static GetOpenAiToolDefinition() {
        return {
            type: "function",
            function: {
                name: "file_system",
                description: "Perform file system operations like reading, writing, and listing files.",
                parameters: {
                    type: "object",
                    properties: {
                        operation: {
                            type: "string",
                            enum: ["read_file", "write_file", "list_dir"],
                            description: "The operation to perform."
                        },
                        path: {
                            type: "string",
                            description: "The absolute path to the file or directory."
                        },
                        content: {
                            type: "string",
                            description: "The content to write (required for write_file)."
                        }
                    },
                    required: ["operation", "path"]
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
                name: "file_system",
                description: "Perform file system operations like reading, writing, and listing files.",
                parameters: {
                    type: "object",
                    properties: {
                         operation: {
                            type: "string",
                            enum: ["read_file", "write_file", "list_dir"],
                            description: "The operation to perform."
                        },
                        path: {
                            type: "string",
                            description: "The absolute path to the file or directory."
                        },
                        content: {
                            type: "string",
                            description: "The content to write (required for write_file)."
                        }
                    },
                    required: ["operation", "path"]
                }
            }]
        }
    }

    /**
     * Execute a tool call from the LLM
     * @param toolCall - The tool call object from the LLM
     * @returns The tool response message
     */
    static ExecuteToolCall(toolCall) {
        if (toolCall.Name != "file_system") {
            return
        }

        try {
            args := toolCall.Arguments
            
            if (!args.Has("operation")) {
                 msg := ChatMessage("tool")
                 msg.Contents.Push(FunctionResultContent(toolCall.Id, "Error: Missing required parameter 'operation'"))
                 return msg
            }

             if (!args.Has("path")) {
                 msg := ChatMessage("tool")
                 msg.Contents.Push(FunctionResultContent(toolCall.Id, "Error: Missing required parameter 'path'"))
                 return msg
            }

            operation := args["operation"]
            path := args["path"]
            result := ""

            if (operation == "read_file") {
                result := FileSystemTool.ReadFile(path)
            } else if (operation == "write_file") {
                 if (!args.Has("content")) {
                     result := "Error: Missing required parameter 'content' for write_file"
                 } else {
                     result := FileSystemTool.WriteFile(path, args["content"])
                 }
            } else if (operation == "list_dir") {
                result := FileSystemTool.ListDir(path)
            } else {
                result := "Error: Unknown operation '" . operation . "'"
            }

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
