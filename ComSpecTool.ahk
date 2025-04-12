class ComSpecTool {
    RunWaitOne(command) {
        shell := ComObject("WScript.Shell")
        ; Execute a single command via cmd.exe
        exec := shell.Exec(A_ComSpec " /C " command)
        ; Read and return the command's output
        return exec.StdOut.ReadAll()
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

    GetToolDefinition() {
        return {
            type: "function",
            function: {
                name: "execute_command",
                description: "Execute a command in Windows Command Prompt (cmd.exe)",
                parameters: {
                    type: "object",
                    properties: {
                        command: {
                            type: "string",
                            description: "The command to execute in cmd.exe"
                        }
                    },
                    required: ["command"]
                }
            }
        }
    }

    ExecuteToolCall(toolCall) {
        if (toolCall.function.name != "execute_command") {
            return
        }

        try {
            args := JSON.parse(toolCall.function.arguments)
            if (args.Has("command")) {
                result := this.RunWaitOne(args["command"])
                return { role: "tool", content: result, tool_call_id: toolCall.id }
            }
        } catch as e {
            return { role: "tool", content: "Error: " e.Message, tool_call_id: toolCall.id }
        }
    }

    ;     MsgBox RunWaitOne("dir " A_ScriptDir)

    ;     MsgBox RunWaitMany("
    ; (
    ; echo Put your commands here,
    ; echo each one will be run,
    ; echo and you'll get the output.
    ; )")
}
