class ExecuteToolCallsCommand {
    sessionManager := ""
    llmService := ""
    systemPrompts := ""

    __New(sessionManager, llmService, systemPrompts) {
        this.sessionManager := sessionManager
        this.llmService := llmService
        this.systemPrompts := systemPrompts
    }

    Execute(sessionIndex := 0) {
        if (!sessionIndex)
            sessionIndex := this.sessionManager.currentSessionIndex

        messages := this.sessionManager.GetSessionMessages(sessionIndex)
        executedAny := false

        i := 1
        while (i <= messages.Length) {
            msg := messages[i]
            if (this.sessionManager.HasToolCalls(msg)) {
                toolResults := this.llmService.ExecuteToolCalls(this.sessionManager, msg, sessionIndex)
                if (toolResults.Length > 0) {
                    this.sessionManager.AddMessagesToSession(sessionIndex, toolResults)
                    executedAny := true
                }
            }
            i++
        }
        return executedAny
    }

    ShouldAutoApprove(msg, sessionIndex := 0) {
        if (!sessionIndex)
            sessionIndex := this.sessionManager.currentSessionIndex

        if (!this.sessionManager.HasToolCalls(msg)) {
            return false
        }

        ; Get current system prompt patterns
        promptIndex := this.sessionManager.GetSessionSystemPrompt(sessionIndex)
        promptNames := this.systemPrompts.GetNames()
        if (promptIndex < 1 || promptIndex > promptNames.Length) {
            return false
        }

        promptName := promptNames[promptIndex]
        patterns := this.systemPrompts.GetToolAutoApprovalPatterns(promptName)

        if (patterns.Count = 0) {
            return false
        }

        ; Check all tool calls against patterns
        toolCalls := this.sessionManager.GetToolCalls(msg)
        for toolCall in toolCalls {
            if (!this.MatchesPattern(toolCall, patterns)) {
                return false
            }
        }

        return true
    }

    MatchesPattern(toolCall, patterns) {
        patternKey := toolCall.Name

        if (!patterns.Has(patternKey)) {
            return false
        }

        toolPatterns := patterns[patternKey]
        args := toolCall.Arguments

        ; All defined patterns must match
        for paramName, regexPattern in toolPatterns {
            if (!args.Has(paramName)) {
                ; If arg not specified but pattern is .*, allow it
                if (regexPattern != ".*") {
                    return false
                }
                continue
            }

            paramValue := args[paramName]
            try {
                if (!RegExMatch(paramValue, regexPattern)) {
                    return false
                }
            } catch {
                ; Invalid regex pattern - fail safe by not auto-approving
                return false
            }
        }

        return true
    }
}
