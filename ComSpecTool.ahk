class ComSpecTool {
    RunWaitOne(command, working_directory := A_ScriptDir) {
        shell := ComObject("WScript.Shell")

        ; Properly quote and construct the full cmd line
        ; DO NOT add a trailing '"' after the command
        cmd := A_ComSpec ' /C "cd /d "' working_directory '" && ' command '"'

        ; Execute using WScript.Shell
        exec := shell.Exec(cmd)

        ; Read output and error
        output := exec.StdOut.ReadAll()
        errorOutput := exec.StdErr.ReadAll()

        if (output = "" && errorOutput != "")
            return "Error: " errorOutput
        if (output = "")
            return "Error: Command returned no output."

        return output
    }

    RunWaitMany(commands) {
        shell := ComObject("WScript.Shell")
        ; Open cmd.exe with echoing of commands disabled
        exec := shell.Exec(A_ComSpec " /Q /K echo off")
        ; Send the commands to execute, separated by newline
        exec.StdIn.WriteLine(commands "`nexit")  ; Always exit at the end!
        ; Read and return the output of all commands
        return exec.StdOut.ReadAll()
    }

    GetOpenAiToolDefinition() {
        return {
            type: "function",
            function: {
                name: "execute_command",
                description: "Execute a command in Windows Command Prompt (cmd.exe) via WScript.Shell",
                parameters: {
                    type: "object",
                    properties: {
                        command: {
                            type: "string",
                            description: "The command to execute in cmd.exe"
                        },
                        working_directory: {
                            type: "string",
                            description: "The working directory for the command"
                        }
                    },
                    required: ["command", "working_directory"]
                }
            }
        }
    }

    GetGeminiToolDefinition() {
        return {
            functionDeclarations: [
                {
                    name: "execute_command",
                    description: "Execute a command in Windows Command Prompt (cmd.exe) via WScript.Shell",
                    parameters: {
                        type: "object",
                        properties: {
                            command: {
                                type: "string",
                                description: "The command to execute in cmd.exe"
                            },
                            working_directory: {
                                type: "string",
                                description: "The working directory for the command"
                            }
                        },
                        required: ["command", "working_directory"]
                    }
                }
            ]
        }
    }

    ExecuteToolCall(toolCall) {
        if (toolCall.function.name != "execute_command") {
            return
        }

        try {
            args := JSON.parse(toolCall.function.arguments)
            if (args.Has("command")) {
                result := this.RunWaitOne(args["command"], args["working_directory"])
                return { role: "tool", content: result, tool_call_id: toolCall.id }
            }
        } catch as e {
            return { role: "tool", content: "Error: " e.Message, tool_call_id: toolCall.id }
        }
    }
}
