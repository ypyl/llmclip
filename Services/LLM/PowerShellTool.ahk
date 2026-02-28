#Include ..\..\Lib\Json.ahk

class PowerShellTool {
    currentProcessPid := 0
    isCancelled := false

    ; Detect best available PowerShell executable (pwsh is faster than powershell)
    static PsExe := FileExist(EnvGet("ProgramFiles") "\PowerShell\7\pwsh.exe")
        ? '"' . EnvGet("ProgramFiles") . '\PowerShell\7\pwsh.exe"'
        : "powershell.exe"

    /**
     * Execute a PowerShell script and return the output
     * @param script - The PowerShell script to execute
     * @param workingDirectory - The working directory for the script (optional)
     * @returns The output from the PowerShell script
     */
    ExecuteScript(script, workingDirectory := A_ScriptDir) {
        ; Unique temp file names
        tempDir := TempFileManager.TempDir
        tmpScript := tempDir "\ahk_ps_" A_TickCount ".ps1"
        tmpOut    := tempDir "\ahk_ps_" A_TickCount "_out.txt"

        try {
            ; Write script to temp .ps1 file — avoids -Command quoting hell
            scriptContent := "Set-Location -LiteralPath '" . workingDirectory . "'`n"
                . "$ErrorActionPreference = 'Continue'`n"
                . script
            FileOpen(tmpScript, "w", "UTF-8-RAW").Write(scriptContent)

            ; Must wrap in cmd /c so the > redirect is handled by the shell
            psExe := PowerShellTool.PsExe
            psCmd := 'cmd.exe /c "' . psExe
                . ' -NoProfile -NonInteractive -ExecutionPolicy Bypass'
                . ' -File "' . tmpScript . '"'
                . ' > "' . tmpOut . '" 2>&1"'

            ; Run hidden, get PID of cmd.exe wrapper
            this.isCancelled := false
            pid := 0
            Run(psCmd, "", "Hide", &pid)
            this.currentProcessPid := pid

            ; Wait for cmd.exe (and its child powershell) to finish
            while ProcessExist(pid) {
                if (this.isCancelled) {
                    ; Kill the whole process tree
                    try RunWait('taskkill /F /T /PID ' . pid,, "Hide")
                    this.currentProcessPid := 0
                    return "Operation cancelled by user"
                }
                Sleep(50)
            }

            this.currentProcessPid := 0

            ; Read output file
            result := ""
            if FileExist(tmpOut) {
                result := FileRead(tmpOut, "UTF-8")
                result := RTrim(result, "`r`n")
            }

            if (result = "") {
                result := "Command executed successfully (no output)"
            }

            return result

        } catch as e {
            return "Error executing PowerShell script: " . e.Message
        } finally {
            ; Always clean up temp files
            try FileDelete(tmpScript)
            try FileDelete(tmpOut)
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
                            description: "The PowerShell script to execute. Can be a single command or multiple commands separated by semicolons or newlines."
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
                            description: "The PowerShell script to execute. Can be a single command or multiple commands separated by semicolons or newlines."
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
    ExecuteToolCall(toolCall) {
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

            workingDir := args.Has("working_directory") ? args["working_directory"] : A_ScriptDir

            result := this.ExecuteScript(args["script"], workingDir)

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
     * Cancel the PowerShell execution
     */
    Cancel() {
        this.isCancelled := true
        if (this.currentProcessPid > 0) {
            try RunWait('taskkill /F /T /PID ' . this.currentProcessPid,, "Hide")
            this.currentProcessPid := 0
        }
    }
}
