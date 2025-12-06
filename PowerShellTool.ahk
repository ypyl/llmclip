#Include <Json>

class PowerShellTool {
    /**
     * Execute a PowerShell script and return the output
     * @param script - The PowerShell script to execute
     * @param workingDirectory - The working directory for the script (optional)
     * @returns The output from the PowerShell script
     */
    static ExecuteScript(script, workingDirectory := A_ScriptDir) {
        try {
            shell := ComObject("WScript.Shell")

            ; Construct the PowerShell command
            ; -NoProfile: Don't load PowerShell profile (faster)
            ; -NonInteractive: Don't prompt for user input
            ; -ExecutionPolicy Bypass: Allow script execution
            ; -Command: Execute the provided script
            psCommand := 'powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "'
                . 'Set-Location -Path \"' . workingDirectory . '\"; '
                . script . '"'

            ; Execute the PowerShell command
            exec := shell.Exec(psCommand)

            ; Read output and error streams
            output := exec.StdOut.ReadAll()
            errorOutput := exec.StdErr.ReadAll()

            ; Wait for the process to complete
            while (exec.Status = 0) {
                Sleep(50)
            }

            exitCode := exec.ExitCode

            ; Build result message
            result := ""
            if (output != "") {
                result .= output
            }

            if (errorOutput != "") {
                if (result != "") {
                    result .= "`n`n--- Errors ---`n"
                }
                result .= errorOutput
            }

            if (exitCode != 0 && result = "") {
                result := "Command failed with exit code: " . exitCode
            }

            if (result = "") {
                result := "Command executed successfully (no output)"
            }

            return result

        } catch as e {
            return "Error executing PowerShell script: " . e.Message
        }
    }

    /**
     * Get the OpenAI tool definition for this tool
     */
    static GetOpenAiToolDefinition() {
        return {
            type: "function",
            function: {
                name: "execute_powershell",
                description: "Execute a PowerShell script. Can be used for file operations, command execution, system queries, and more. The script runs with ExecutionPolicy Bypass.",
                parameters: {
                    type: "object",
                    properties: {
                        script: {
                            type: "string",
                            description: "The PowerShell script to execute. Can be a single command or multiple commands separated by semicolons. Examples: 'Get-ChildItem', 'Get-Content file.txt', 'Set-Content -Path file.txt -Value `"content`"', 'Remove-Item file.txt'"
                        },
                        working_directory: {
                            type: "string",
                            description: "The working directory for the script execution. Defaults to the script directory if not specified."
                        }
                    },
                    required: ["script"]
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
                name: "execute_powershell",
                description: "Execute a PowerShell script. Can be used for file operations, command execution, system queries, and more. The script runs with ExecutionPolicy Bypass.",
                parameters: {
                    type: "object",
                    properties: {
                        script: {
                            type: "string",
                            description: "The PowerShell script to execute. Can be a single command or multiple commands separated by semicolons. Examples: 'Get-ChildItem', 'Get-Content file.txt', 'Set-Content -Path file.txt -Value `"content`"', 'Remove-Item file.txt'"
                        },
                        working_directory: {
                            type: "string",
                            description: "The working directory for the script execution. Defaults to the script directory if not specified."
                        }
                    },
                    required: ["script"]
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
        if (toolCall.Name != "execute_powershell") {
            return
        }

        try {
            args := toolCall.Arguments

            if (!args.Has("script")) {
                msg := ChatMessage("tool")
                msg.Contents.Push(FunctionResultContent(toolCall.Id, "Error: Missing required parameter 'script'"))
                return msg
            }

            ; Get working directory if provided, otherwise use default
            workingDir := args.Has("working_directory") ? args["working_directory"] : A_ScriptDir

            ; Execute the PowerShell script
            result := PowerShellTool.ExecuteScript(args["script"], workingDir)

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
