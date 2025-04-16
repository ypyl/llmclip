#Requires AutoHotkey 2.0
#Include <Json>

class AppSettings {
    providers := Map()
    selectedLLMType := ""
    llmTypes := []
    selectedIndex := 1
    selectedSystemPromptIndex := 1

    __New() {
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
                this.selectedIndex := A_Index
            }
        }
    }

    GetSelectedSettings() {
        selectedLLMType := this.llmTypes[this.selectedIndex]
        settings := this.providers[selectedLLMType]
        settings["type"] := selectedLLMType  ; Add type to settings
        return settings
    }

    GetSystemPromptValue() {
        defaultPrompt := "You are a helpful assistant. Be concise and direct in your responses."
        settings := this.GetSelectedSettings()
        if (prompts := settings.Get("system_prompts", "")) {
            if (prompts.Length >= this.selectedSystemPromptIndex)
                defaultPrompt := prompts[this.selectedSystemPromptIndex]["value"]
            else if (prompts.Length > 0)
                defaultPrompt := prompts[1]["value"]
        }
        return defaultPrompt
    }

    GetSystemPromptNames() {
        settings := this.GetSelectedSettings()
        names := []
        if (prompts := settings.Get("system_prompts", "")) {
            for prompt in prompts {
                names.Push(prompt["name"])
            }
            ; Reset selectedSystemPromptIndex if out of range
            if (this.selectedSystemPromptIndex > names.Length || this.selectedSystemPromptIndex < 1) {
                this.selectedSystemPromptIndex := 1
            }
            return names
        }
        return []
    }
}
