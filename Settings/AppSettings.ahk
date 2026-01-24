#Requires AutoHotkey 2.0
#Include <Json>
#Include SystemPrompts.ahk
#Include Providers.ahk
#Include Roles.ahk

class AppSettings {
    providers := unset
    selectedLLMType := ""
    selectedLLMTypeIndex := 1
    llmTypes := []
    ollamaApiKey := ""
    
    systemPromptsManager := unset
    providersManager := unset
    rolesManager := unset

    __New() {
        this.systemPromptsManager := SystemPrompts()
        this.providersManager := Providers()
        this.rolesManager := Roles()
        this.Reload()
    }

    Reload() {
        settings := JSON.LoadFile("settings.json")
        
        this.systemPromptsManager.Reload()
        this.providersManager.Reload()
        this.rolesManager.Reload()
        
        this.providers := this.providersManager.GetAll()
        
        this.selectedLLMType := settings["selectedLLMType"]
        if (settings.Has("ollama_api_key")) {
            this.ollamaApiKey := settings["ollama_api_key"]
        } else {
            this.ollamaApiKey := ""
        }

        ; Initialize LLM types
        this.llmTypes := []
        for key in this.providers {
            this.llmTypes.Push(key)
            if (key = this.selectedLLMType) {
                this.selectedLLMTypeIndex := A_Index
            }
        }
    }

    GetSelectedSettings(llmIndex) {
        if (llmIndex > this.llmTypes.Length || llmIndex < 1)
            return Map()

        selectedLLMType := this.llmTypes[llmIndex]
        settings := this.providersManager.Get(selectedLLMType)
        settings["type"] := selectedLLMType  ; Add type to settings
        
        ; Load API key from keys.ini
        if (FileExist("Settings\keys.ini")) {
            apiKey := IniRead("Settings\keys.ini", "Keys", selectedLLMType, "")
            if (apiKey != "") {
                settings["api_key"] := apiKey
            }
        }
        
        return settings
    }

    GetVisiblePrompts(llmIndex) {
        if (llmIndex > this.llmTypes.Length || llmIndex < 1)
            return []

        selectedLLMType := this.llmTypes[llmIndex]
        promptNames := this.rolesManager.GetPromptsForProvider(selectedLLMType)
        
        visiblePrompts := []
        for name in promptNames {
            promptData := this.systemPromptsManager.Get(name)
            if (promptData.Count > 0) {
                ; Clone prompt data and inject name
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

    GetSystemPromptValue(llmIndex, promptIndex) {
        defaultPrompt := "You are a helpful assistant. Be concise and direct in your responses."
        prompts := this.GetVisiblePrompts(llmIndex)
        if (prompts.Length >= promptIndex) {
            value := prompts[promptIndex]["value"]
            if (FileExist(value)) {
                value := FileRead(value)
            }
            
            ; Add current date and time
            currentTime := FormatTime(, "yyyy-MM-dd HH:mm:ss")
            value .= "`n`nCurrent Date and Time: " . currentTime
            
            return value
        }
        return defaultPrompt . "`n`nCurrent Date and Time: " . FormatTime(, "yyyy-MM-dd HH:mm:ss")
    }

    GetInputTemplate(llmIndex, promptIndex) {
        defaultPrompt := ""
        prompts := this.GetVisiblePrompts(llmIndex)
        if (prompts.Length >= promptIndex) {
            if (inputTempalte := prompts[promptIndex].Get("input_template", "")) {
                return inputTempalte
            }
        }
        return defaultPrompt
    }

    GetContext(llmIndex, promptIndex) {
        prompts := this.GetVisiblePrompts(llmIndex)
        if (prompts.Length >= promptIndex) {
            if (context := prompts[promptIndex].Get("context", [])) {
                return context
            }
        }
        return []
    }

    IsToolEnabled(llmIndex, toolName) {
        settings := this.GetSelectedSettings(llmIndex)
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

    SetToolEnabled(llmIndex, toolName, enabled) {
        ; NOTE: This modifies memory but NOT the file yet for tools. 
        ; Since settings are split, saving back solely to providers.json might be needed if persistent.
        ; However, original request did not specify full save implementation for tools, 
        ; but typically we should update the providers map in memory and Providers class should handle save?
        ; For now, keeping in-memory update on the provider object retrieved from manager.
        
        settings := this.GetSelectedSettings(llmIndex)
        if (!settings.Has("tools")) {
            settings["tools"] := []
        }
        currentTools := settings["tools"]
        
        if (enabled) {
            ; Add if not present
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
            ; Remove if present
            newTools := []
            for t in currentTools {
                if (t != toolName) {
                    newTools.Push(t)
                }
            }
            settings["tools"] := newTools
        }
    }


    IsImageInputEnabled(llmIndex) {
        settings := this.GetSelectedSettings(llmIndex)
        image := settings.Get("image", false)
        return image
    }

    GetCompressionPrompt(llmIndex) {
        settings := this.GetSelectedSettings(llmIndex)
        defaultPrompt := "Summarize the following conversation, keeping only the most meaningful information and key context. Be concise but preserve all important details. Return only the summary without any preamble."
        return settings.Get("compression_prompt", defaultPrompt)
    }

    GetLearningsPrompt(llmIndex) {
        settings := this.GetSelectedSettings(llmIndex)
        defaultPrompt := "Extract valuable learnings and facts from the following conversation.`nReturn a bulleted list of notes.`nFocus on technical details, solutions, and key decisions."
        return settings.Get("learnings_prompt", defaultPrompt)
    }

    GetSystemPromptNames(llmIndex) {
        names := []
        prompts := this.GetVisiblePrompts(llmIndex)
        for prompt in prompts {
            names.Push(prompt["name"])
        }
        return names
    }
}
