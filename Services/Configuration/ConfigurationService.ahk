#Include SystemPrompts.ahk
#Include Providers.ahk
#Include Roles.ahk

class ConfigurationService {
    static instance := ""

    ; Configuration data
    providers := Map()
    models := []
    modelDisplayNames := []
    ollamaApiKey := ""

    ; Sub-managers
    systemPromptsManager := unset
    providersManager := unset
    rolesManager := unset

    static GetInstance() {
        if (!ConfigurationService.instance)
            ConfigurationService.instance := ConfigurationService()
        return ConfigurationService.instance
    }

    __New() {
        this.systemPromptsManager := SystemPrompts()
        this.providersManager := Providers()
        this.rolesManager := Roles()
        this.LoadAll()
    }

    LoadAll() {
        this.LoadAppSettings()
        this.systemPromptsManager.Reload()
        this.providersManager.Reload()
        this.rolesManager.Reload()

        this.providers := this.providersManager.GetAll()

        this.models := []
        this.modelDisplayNames := []
        for providerName, providerEntry in this.providers {
            for modelName in providerEntry["models"] {
                this.models.Push(providerName . "/" . modelName)
                this.modelDisplayNames.Push(providerName . ": " . modelName)
            }
        }
    }

    LoadAppSettings() {
        if (FileExist("keys.ini")) {
            this.ollamaApiKey := IniRead("keys.ini", "Ollama Cloud", "api_key", "")
        } else {
            this.ollamaApiKey := ""
        }
    }

    GetApiKey(selectedLLMType, providerName := "") {
        if (FileExist("keys.ini")) {
            key := ""
            if (providerName != "") {
                key := IniRead("keys.ini", providerName, "api_key", "")
            }
            if (key == "") {
                key := IniRead("keys.ini", "Keys", selectedLLMType, "")
            }
            return key
        }
        return ""
    }

    GetSelectedSettings(modelIndex) {
        if (modelIndex > this.models.Length || modelIndex < 1)
            return Map()

        selectedModel := this.models[modelIndex]
        parts := StrSplit(selectedModel, "/", , 2)
        settings := this.providersManager.Get(parts[1], parts[2])
        settings["type"] := selectedModel

        apiKey := this.GetApiKey(selectedModel, parts[1])
        if (apiKey != "") {
            settings["api_key"] := apiKey
        }

        return settings
    }

    GetVisiblePrompts(modelIndex) {
        if (modelIndex > this.models.Length || modelIndex < 1)
            return []

        selectedModel := this.models[modelIndex]
        promptNames := this.rolesManager.GetPromptsForProvider(selectedModel)

        ; If no prompts returned (roles disabled), use all system prompts
        if (promptNames.Length = 0) {
            promptNames := this.systemPromptsManager.GetNames()
        }

        visiblePrompts := []
        for name in promptNames {
            promptData := this.systemPromptsManager.Get(name)
            if (promptData.Count > 0) {
                promptEntry := Map()
                promptEntry["name"] := name
                for k, v in promptData {
                    promptEntry[k] := v
                }

                if (!promptEntry.Get("hidden", false)) {
                    visiblePrompts.Push(promptEntry)
                }
            }
        }
        return visiblePrompts
    }

    GetSystemPromptValue(modelIndex, promptIndex) {
        defaultPrompt := "You are a helpful assistant. Be concise and direct in your responses."
        prompts := this.GetVisiblePrompts(modelIndex)
        if (prompts.Length >= promptIndex) {
            value := prompts[promptIndex]["value"]
            
            try {
                pathInSystemPrompts := "prompts\" . value
                if (SubStr(value, 1, 2) = ".\") {
                    pathInSystemPrompts := "prompts\" . SubStr(value, 3)
                }

                if (FileExist(pathInSystemPrompts)) {
                    value := FileRead(pathInSystemPrompts)
                } else if (FileExist(value)) {
                    value := FileRead(value)
                }
            } catch {
                ; Ignore errors for long strings
            }

            return value
        }
        return defaultPrompt
    }

    GetInputTemplate(modelIndex, promptIndex) {
        prompts := this.GetVisiblePrompts(modelIndex)
        if (prompts.Length >= promptIndex) {
            if (inputTemplate := prompts[promptIndex].Get("input_template", "")) {
                return inputTemplate
            }
        }
        return ""
    }

    GetContext(modelIndex, promptIndex) {
        prompts := this.GetVisiblePrompts(modelIndex)
        if (prompts.Length >= promptIndex) {
            if (context := prompts[promptIndex].Get("context", [])) {
                return context
            }
        }
        return []
    }

    IsToolEnabled(modelIndex, toolName) {
        settings := this.GetSelectedSettings(modelIndex)
        tools := settings.Get("tools", [])
        if (tools is Array) {
            for t in tools {
                if (t = toolName)
                    return true
            }
            return false
        }
        return false
    }

    SetToolEnabled(modelIndex, toolName, enabled) {
        settings := this.GetSelectedSettings(modelIndex)
        if (!settings.Has("tools")) {
            settings["tools"] := []
        }
        currentTools := settings["tools"]

        if (enabled) {
            hasTool := false
            for t in currentTools {
                if (t = toolName) {
                    hasTool := true
                    break
                }
            }
            if (!hasTool) {
                currentTools.Push(toolName)
            }
        } else {
            newTools := []
            for t in currentTools {
                if (t != toolName) {
                    newTools.Push(t)
                }
            }
            settings["tools"] := newTools
        }
    }

    IsImageInputEnabled(modelIndex) {
        settings := this.GetSelectedSettings(modelIndex)
        return settings.Get("image", false)
    }

    GetCompressionPrompt(modelIndex) {
        return "Summarize the following conversation, keeping only the most meaningful information and key context. Be concise but preserve all important details. Return only the summary without any preamble."
    }

    GetLearningsPrompt(modelIndex) {
        settings := this.GetSelectedSettings(modelIndex)
        defaultPrompt := "Extract valuable learnings and facts from the following conversation.`nReturn a bulleted list of notes.`nFocus on technical details, solutions, and key decisions."
        return settings.Get("learnings_prompt", defaultPrompt)
    }

    GetSystemPromptNames(modelIndex) {
        names := []
        prompts := this.GetVisiblePrompts(modelIndex)
        for prompt in prompts {
            names.Push(prompt["name"])
        }
        return names
    }

    Reload() {
        this.LoadAll()
    }

    SaveRawSystemPromptValue(modelIndex, promptName, newText) {
        cleanText := newText

        prompts := this.GetVisiblePrompts(modelIndex)
        for prompt in prompts {
            if (prompt["name"] == promptName) {
                value := prompt["value"]
                
                ; Check if it's a file
                pathInSystemPrompts := "prompts\" . value
                if (SubStr(value, 1, 2) = ".\") {
                    pathInSystemPrompts := "prompts\" . SubStr(value, 3)
                }

                if (FileExist(pathInSystemPrompts)) {
                    FileOpen(pathInSystemPrompts, "w", "UTF-8").Write(cleanText)
                } else if (FileExist(value)) {
                    FileOpen(value, "w", "UTF-8").Write(cleanText)
                } else {
                    ; It's a literal string in JSON
                    this.systemPromptsManager.UpdatePromptValue(promptName, cleanText)
                }
                
                ; Reload to ensure everything is consistent
                this.Reload()
                return true
            }
        }
        return false
    }
}
