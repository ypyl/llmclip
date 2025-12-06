#Requires AutoHotkey 2.0
#Include <Json>

class AppSettings {
    providers := Map()
    selectedLLMType := ""
    selectedLLMTypeIndex := 1
    llmTypes := []

    __New() {
        this.Reload()
    }

    Reload() {
        settings := JSON.LoadFile("settings.json")
        this.providers := Map()
        for provider in settings["providers"] {
            value := settings["providers"][provider]
            this.providers[provider] := Map()
            for k, v in value
                this.providers[provider][k] := v
        }
        this.selectedLLMType := settings["selectedLLMType"]

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
        selectedLLMType := this.llmTypes[llmIndex]
        settings := this.providers[selectedLLMType]
        settings["type"] := selectedLLMType  ; Add type to settings
        return settings
    }

    GetVisiblePrompts(llmIndex) {
        settings := this.GetSelectedSettings(llmIndex)
        visiblePrompts := []
        if (prompts := settings.Get("system_prompts", [])) {
            for prompt in prompts {
                if (!prompt.Get("hidden", false)) {
                    visiblePrompts.Push(prompt)
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
                return FileRead(value)
            }
            return value
        }
        return defaultPrompt
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
